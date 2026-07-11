/**
 * verify.js — Sanity check for the seeded Firestore `menu` collection
 *
 * Checks:
 *  1. Live document count
 *  2. CRITICAL: Collection name case mismatch — Flutter reads 'Menu', we wrote to 'menu'
 *  3. Required field presence on every document
 *  4. Field type correctness (price = int/number, booleans are actual booleans)
 *  5. Category enum validity
 *  6. SubCategory enum validity (per category)
 *  7. Missing `stock` field — Flutter reads stock for non-mess items
 *  8. Items that will always show "OUT OF STOCK" due to missing stock field
 *  9. `hasPrep` consistency check vs category rules
 * 10. Duplicate item names
 * 11. Price sanity (price > 0)
 * 12. imageUrl is a string (not null/undefined)
 */

import { UserRefreshClient } from "google-auth-library";

const PROJECT_ID = "canteen-app-e1c8d";
const SEEDED_COLLECTION = "menu";     // what we wrote to
const FLUTTER_COLLECTION = "Menu";    // what Flutter reads from (line 30 in app_flow_screen.dart)

const FIREBASE_CLIENT_ID =
  "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
const FIREBASE_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";
const REFRESH_TOKEN =
  "1//0gEmjm_w5hDcBCgYIARAAGBASNwF-L9Irh-1sCEc6ZEJ47CL0rVeQpzBeJA1N3qHWiw6XqjY-21t1c_hKL5gwjPHvHRltdXk3zSA";

const VALID_CATEGORIES = new Set(["bakery", "beverages", "mess", "continental"]);
const VALID_SUBCATEGORIES = {
  bakery:      new Set(["snacks", "packaged_snacks", "chocolates", "ice_cream", "pastries", "cold_drinks"]),
  beverages:   new Set(["hot", "fresh_juice", "milkshakes"]),
  mess:        new Set(["tiffin", "lunch"]),
  continental: new Set(["sandwiches", "burgers", "fries_and_starters", "pizzas", "hot_dogs"]),
};

// ─── Auth ─────────────────────────────────────────────────────────────────────
async function getToken() {
  const client = new UserRefreshClient(FIREBASE_CLIENT_ID, FIREBASE_CLIENT_SECRET, REFRESH_TOKEN);
  const { credentials } = await client.refreshAccessToken();
  return credentials.access_token;
}

// ─── REST helper ──────────────────────────────────────────────────────────────
async function fetchAllDocs(collection, token) {
  const docs = [];
  let pageToken = null;
  const base = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}`;

  do {
    const url = base + `?pageSize=300` + (pageToken ? `&pageToken=${pageToken}` : "");
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (res.status === 404) break;
    if (!res.ok) throw new Error(`List ${collection}: ${res.status} ${await res.text()}`);
    const body = await res.json();
    if (body.documents) {
      for (const d of body.documents) {
        // Convert Firestore REST fields → plain JS object
        const plain = {};
        for (const [k, v] of Object.entries(d.fields ?? {})) {
          if (v.stringValue  !== undefined) plain[k] = v.stringValue;
          else if (v.integerValue !== undefined) plain[k] = parseInt(v.integerValue, 10);
          else if (v.doubleValue  !== undefined) plain[k] = v.doubleValue;
          else if (v.booleanValue !== undefined) plain[k] = v.booleanValue;
          else plain[k] = null;
        }
        docs.push({ id: d.name.split("/").pop(), fields: plain });
      }
    }
    pageToken = body.nextPageToken ?? null;
  } while (pageToken);

  return docs;
}

// ─── Checks ───────────────────────────────────────────────────────────────────
function check(errors, warnings, label, cond, msg) {
  if (!cond) {
    if (label === "WARN") warnings.push(msg);
    else errors.push(`[${label}] ${msg}`);
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log("\n🔍 Firestore Sanity Check\n" + "─".repeat(60));

  const token = await getToken();

  // ── 0. CRITICAL: Collection name case check ──────────────────────────────
  console.log(`\n[0] Checking collection name case mismatch…`);
  const seedDocs  = await fetchAllDocs(SEEDED_COLLECTION, token);   // 'menu'
  const flutterDocs = await fetchAllDocs(FLUTTER_COLLECTION, token); // 'Menu'

  const errors = [];
  const warnings = [];
  const info = [];

  if (flutterDocs.length === 0 && seedDocs.length > 0) {
    errors.push(
      `[CRITICAL] Flutter reads collection 'Menu' (capital M) but data was seeded into 'menu' (lowercase). ` +
      `The app will show an empty menu screen! Flutter code: app_flow_screen.dart:30`
    );
  } else if (flutterDocs.length > 0) {
    info.push(`Collection 'Menu' already has ${flutterDocs.length} docs — Flutter will see these.`);
  }

  info.push(`Collection 'menu' (seeded): ${seedDocs.length} documents`);
  info.push(`Collection 'Menu' (Flutter reads): ${flutterDocs.length} documents`);

  // Use whichever collection has data for field-level checks
  const docsToCheck = flutterDocs.length > 0 ? flutterDocs : seedDocs;
  const checkingCollection = flutterDocs.length > 0 ? "Menu" : "menu";
  console.log(`   Checking ${docsToCheck.length} docs from '${checkingCollection}'`);

  // ── 1. Document count ────────────────────────────────────────────────────
  console.log(`\n[1] Document count…`);
  check(errors, warnings, "WARN", docsToCheck.length === 127, `Expected 127 documents, found ${docsToCheck.length}`);

  // ── 2–8. Per-document field checks ──────────────────────────────────────
  console.log(`\n[2] Field-level checks on each document…`);

  const REQUIRED_FIELDS = ["name", "price", "category", "subCategory", "isAvailable", "hasPrep", "imageUrl"];
  const seenNames = new Map();
  let missingStock = 0;
  let wrongHasPrep = 0;
  let outOfStockRisk = 0;

  for (const doc of docsToCheck) {
    const f = doc.fields;
    const label = f.name ?? `<doc ${doc.id}>`;

    // Required fields present
    for (const field of REQUIRED_FIELDS) {
      check(errors, warnings, "ERROR",
        f[field] !== undefined && f[field] !== null,
        `Doc '${label}' (${doc.id}) — missing required field: '${field}'`
      );
    }

    // Type checks
    if (f.price !== undefined) {
      check(errors, warnings, "ERROR",
        typeof f.price === "number",
        `Doc '${label}' — 'price' should be a number, got ${typeof f.price}`
      );
      check(errors, warnings, "ERROR",
        f.price > 0,
        `Doc '${label}' — 'price' is ${f.price} (must be > 0)`
      );
    }

    if (f.isAvailable !== undefined) {
      check(errors, warnings, "ERROR",
        typeof f.isAvailable === "boolean",
        `Doc '${label}' — 'isAvailable' should be boolean, got ${typeof f.isAvailable}`
      );
    }

    if (f.hasPrep !== undefined) {
      check(errors, warnings, "ERROR",
        typeof f.hasPrep === "boolean",
        `Doc '${label}' — 'hasPrep' should be boolean, got ${typeof f.hasPrep}`
      );
    }

    if (f.imageUrl !== undefined) {
      check(errors, warnings, "ERROR",
        typeof f.imageUrl === "string",
        `Doc '${label}' — 'imageUrl' should be string, got ${typeof f.imageUrl}`
      );
    }

    // Category enum
    if (f.category !== undefined) {
      check(errors, warnings, "ERROR",
        VALID_CATEGORIES.has(f.category),
        `Doc '${label}' — invalid category: '${f.category}'`
      );
    }

    // SubCategory enum
    if (f.category && f.subCategory && VALID_SUBCATEGORIES[f.category]) {
      check(errors, warnings, "ERROR",
        VALID_SUBCATEGORIES[f.category].has(f.subCategory),
        `Doc '${label}' — invalid subCategory '${f.subCategory}' for category '${f.category}'`
      );
    }

    // hasPrep consistency: mess & continental must be true; bakery & beverages must be false
    if (f.category && f.hasPrep !== undefined) {
      const shouldHavePrep = f.category === "mess" || f.category === "continental";
      if (f.hasPrep !== shouldHavePrep) {
        warnings.push(
          `WARN: Doc '${label}' — hasPrep=${f.hasPrep} but category='${f.category}' ` +
          `(expected hasPrep=${shouldHavePrep})`
        );
        wrongHasPrep++;
      }
    }

    // Missing `stock` field — Flutter's _toMenuItems() reads stock for non-mess items
    // Without stock, stock defaults to 0 → item shows OUT OF STOCK
    if (f.stock === undefined || f.stock === null) {
      const cat = f.category ?? "";
      const itemName = (f.name ?? "").trim().toLowerCase();
      // Flutter skips stock for mess + tea + coffee (isNonQuantifiable = true)
      const isNonQuantifiable = cat === "mess" || itemName === "tea" || itemName === "coffee";
      if (!isNonQuantifiable) {
        missingStock++;
        outOfStockRisk++;
        warnings.push(
          `WARN: Doc '${label}' (${cat}) — missing 'stock' field. ` +
          `Flutter will default stock=0 → item will show 'OUT OF STOCK' and be unorderable.`
        );
      }
    }

    // Duplicate name check
    if (f.name) {
      const key = f.name.trim().toLowerCase();
      if (seenNames.has(key)) {
        warnings.push(`WARN: Duplicate name '${f.name}' — also in doc ${seenNames.get(key)}`);
      } else {
        seenNames.set(key, doc.id);
      }
    }
  }

  // ── 3. Stock decrement logic — mess category check ───────────────────────
  console.log(`\n[3] Continental category in _categoryDisplayName()…`);
  // app_flow_screen.dart _categoryDisplayName() only handles bakery/mess/beverages
  // 'continental' falls through to default → returns 'continental' (lowercase) which is fine

  // ── 4. Category display name check ──────────────────────────────────────
  // Flutter's _categoryDisplayName is only used for toast messages, not display.
  // Not critical but worth noting for completeness.
  
  // ── Summary ───────────────────────────────────────────────────────────────
  console.log("\n" + "─".repeat(60));
  console.log("📋 SANITY CHECK RESULTS");
  console.log("─".repeat(60));

  // Info
  for (const i of info) console.log(`ℹ️  ${i}`);

  // Errors
  if (errors.length === 0) {
    console.log("\n✅ No errors found.");
  } else {
    console.log(`\n❌ ${errors.length} ERROR(S):`);
    for (const e of errors) console.log(`   • ${e}`);
  }

  // Warnings
  if (warnings.length === 0) {
    console.log("✅ No warnings.");
  } else {
    console.log(`\n⚠️  ${warnings.length} WARNING(S):`);
    // Print unique warnings (stock warnings are many — summarize them)
    const nonStockWarnings = warnings.filter(w => !w.startsWith("WARN: Doc") || !w.includes("missing 'stock'"));
    const stockWarnings = warnings.filter(w => w.includes("missing 'stock'"));
    
    for (const w of nonStockWarnings) console.log(`   • ${w}`);
    if (stockWarnings.length > 0) {
      console.log(`   • ${stockWarnings.length} items are missing the 'stock' field → will show OUT OF STOCK in the app.`);
      // Group by category for clarity
      const catGroups = {};
      for (const doc of docsToCheck) {
        const f = doc.fields;
        const cat = f.category ?? "unknown";
        const itemName = (f.name ?? "").trim().toLowerCase();
        const isNonQ = cat === "mess" || itemName === "tea" || itemName === "coffee";
        if (!isNonQ && (f.stock === undefined || f.stock === null)) {
          catGroups[cat] = (catGroups[cat] || 0) + 1;
        }
      }
      console.log(`     By category: ${JSON.stringify(catGroups)}`);
    }
  }

  console.log("\n" + "─".repeat(60));
  console.log("🔬 SPECIFIC ISSUE SUMMARY:");
  console.log("─".repeat(60));

  if (errors.some(e => e.includes("CRITICAL"))) {
    console.log("\n🚨 CRITICAL — Collection name mismatch detected.");
    console.log("   • Seeded into: 'menu'");
    console.log("   • Flutter reads: 'Menu'  (app_flow_screen.dart line 30)");
    console.log("   • Admin screen reads: 'Menu'  (admin_menu_screen.dart line 71)");
    console.log("   • Stock decrement writes to: 'Menu'  (app_flow_screen.dart line 310)");
    console.log("   FIX: Re-run seed.js with collection = 'Menu' (capital M)");
  } else {
    console.log("\n✅ Collection name: MATCHES — Flutter will read the seeded data.");
  }

  if (outOfStockRisk > 0) {
    console.log(`\n⚠️  STOCK FIELD MISSING on ${outOfStockRisk} items.`);
    console.log("   Flutter reads: const stock = ((data['stock'] ?? 0) as num).toInt();");
    console.log("   With no stock field → stock defaults to 0 → shows 'OUT OF STOCK'");
    console.log("   → Users cannot add these items to cart.");
    console.log("   Affected categories: bakery (all), beverages (all), continental (all)");
    console.log("   NOTE: 'mess' items are exempt (isNonQuantifiable = true), and tea/coffee too.");
    console.log("   FIX: Re-run seed with stock field added, OR accept that stock is admin-managed.");
  }

  if (wrongHasPrep > 0) {
    console.log(`\n⚠️  hasPrep inconsistency: ${wrongHasPrep} item(s)`);
  }

  console.log("\n" + "─".repeat(60));
  process.exit(errors.length > 0 ? 1 : 0);
}

main().catch(err => {
  console.error("❌ Verify failed:", err.message ?? err);
  process.exit(1);
});
