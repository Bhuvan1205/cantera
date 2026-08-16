/**
 * seed.js — Firestore REST API seeder for Canteen App
 *
 * Uses the Firebase CLI's cached OAuth2 token to authenticate.
 * Reads DataSets/menu_dataset.csv and strictly pushes it.
 *
 * Usage:  node seed.js
 */

import { UserRefreshClient } from "google-auth-library";
import fs from "fs";
import csv from "csv-parser";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROJECT_ID = "canteen-app-e1c8d";
const COLLECTION = "Menu";
const BASE_URL = process.env.FIRESTORE_EMULATOR_HOST
  ? `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents`
  : `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

const FIREBASE_CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
const FIREBASE_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";
const REFRESH_TOKEN = "1//0gEmjm_w5hDcBCgYIARAAGBASNwF-L9Irh-1sCEc6ZEJ47CL0rVeQpzBeJA1N3qHWiw6XqjY-21t1c_hKL5gwjPHvHRltdXk3zSA";

async function getAccessToken() {
  if (process.env.FIRESTORE_EMULATOR_HOST) return "";
  const client = new UserRefreshClient(FIREBASE_CLIENT_ID, FIREBASE_CLIENT_SECRET, REFRESH_TOKEN);
  const { credentials } = await client.refreshAccessToken();
  return credentials.access_token;
}

function toFirestoreFields(obj) {
  const fields = {};
  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === "string") {
      fields[key] = { stringValue: value };
    } else if (typeof value === "number") {
      fields[key] = { integerValue: String(value) };
    } else if (typeof value === "boolean") {
      fields[key] = { booleanValue: value };
    }
  }
  return fields;
}

async function listDocumentNames(token) {
  const names = [];
  let pageToken = null;
  do {
    const url = `${BASE_URL}/${COLLECTION}?pageSize=300&mask.fieldPaths=name` + (pageToken ? `&pageToken=${pageToken}` : "");
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!res.ok) {
      if (res.status === 404) break;
      throw new Error(`List failed (${res.status}): ${await res.text()}`);
    }
    const body = await res.json();
    if (body.documents) {
      body.documents.forEach((d) => names.push(d.name));
    }
    pageToken = body.nextPageToken ?? null;
  } while (pageToken);
  return names;
}

async function deleteDocument(name, token) {
  const url = `https://firestore.googleapis.com/v1/${name}`;
  const res = await fetch(url, { method: "DELETE", headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok && res.status !== 404) {
    throw new Error(`Delete failed (${res.status}): ${await res.text()}`);
  }
}

async function createDocumentWithId(id, item, token) {
  const url = `${BASE_URL}/${COLLECTION}?documentId=${id}`;
  const body = JSON.stringify({ fields: toFirestoreFields(item) });
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body,
  });

  if (!res.ok) {
    throw new Error(`Create failed (${res.status}): ${await res.text()}`);
  }
}

async function parseCSV(filePath) {
  return new Promise((resolve, reject) => {
    const results = [];
    fs.createReadStream(filePath)
      .pipe(csv())
      .on("data", (data) => results.push(data))
      .on("end", () => resolve(results))
      .on("error", (err) => reject(err));
  });
}

async function main() {
  console.log("🚀 Starting Firestore menu seed (via REST API)…");
  console.log(`   Project    : ${PROJECT_ID}`);
  console.log(`   Collection : ${COLLECTION}`);

  console.log("\n🔑 Obtaining access token…");
  const token = await getAccessToken();
  console.log("   ✅ Token obtained.");

  console.log("\nStep 1 ▸ Parsing CSV...");
  const csvPath = path.join(__dirname, "..", "..", "DataSets", "menu_dataset.csv");
  const records = await parseCSV(csvPath);
  console.log(`   Found ${records.length} items in CSV.`);

  const menuItems = records.map((record) => {
    const cat = record.category.toLowerCase().trim();
    let subCat = "";
    if (cat === "bakery") subCat = "snacks";
    else if (cat === "beverages") subCat = "hot";
    else if (cat === "mess") subCat = "lunch";
    
    return {
      id: record.item_id.trim(),
      name: record.item_name.trim(),
      price: parseInt(record.price.trim(), 10),
      category: cat,
      subCategory: subCat,
      stock: 50,
      isAvailable: true,
      hasPrep: cat === "mess",
      imageUrl: "",
    };
  });

  console.log("\nStep 2 ▸ Listing existing documents…");
  let existingNames = [];
  try {
    existingNames = await listDocumentNames(token);
  } catch (e) {
    console.log("   ⚠️ Could not list existing documents, skipping delete.");
  }
  console.log(`   Found ${existingNames.length} existing document(s).`);

  if (existingNames.length > 0) {
    console.log("   Deleting…");
    let delCount = 0;
    for (const name of existingNames) {
      await deleteDocument(name, token);
      delCount++;
      if (delCount % 20 === 0) console.log(`   🗑  ${delCount} / ${existingNames.length} deleted…`);
    }
    console.log(`   ✅ Deleted all ${existingNames.length} document(s).`);
  }

  console.log("\nStep 3 ▸ Inserting menu items…");
  let insCount = 0;
  for (const item of menuItems) {
    const { id, ...data } = item;
    await createDocumentWithId(id, data, token);
    insCount++;
    if (insCount % 20 === 0) console.log(`   📝 ${insCount} / ${menuItems.length} inserted…`);
  }

  console.log(`\n✅ Done! Total documents inserted: ${insCount}`);
}

main().catch((err) => {
  console.error("\n❌ Seeding failed:", err.message ?? err);
  process.exit(1);
});
