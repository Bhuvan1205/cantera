import os
import sys
import re

# Add backend directory to sys.path to import config.firebase
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../lib/admin_console/backend"))
sys.path.append(backend_path)

os.environ["FIRESTORE_EMULATOR_HOST"] = "127.0.0.1:9090"
os.environ["GCLOUD_PROJECT"] = "canteen-app-e1c8d"

from config.firebase import db


def make_doc_id(name: str) -> str:
    """
    Produce a stable, deterministic Firestore document ID from the item name.
    Rules:
      - Lowercase
      - Spaces and special chars → underscore
      - Multiple underscores collapsed to one
      - Strip leading/trailing underscores
    Examples:
      "Egg Puff"                    → "egg_puff"
      "Samosa Small 4 Pieces"       → "samosa_small_4_pieces"
      "BRU Cold Coffee"             → "bru_cold_coffee"
      "Ice Cream 10"                → "ice_cream_10"
    """
    slug = name.lower()
    slug = re.sub(r"[^a-z0-9]+", "_", slug)
    slug = slug.strip("_")
    return slug


# Read scripts/seed/seed.js
seed_js_path = os.path.join(os.path.dirname(__file__), "seed/seed.js")
with open(seed_js_path, "r", encoding="utf-8") as f:
    content = f.read()

# Extract the menuItems array using regex
match = re.search(r"const menuItems = \[(.*?)\];", content, re.DOTALL)
if not match:
    print("Could not find menuItems array in seed.js")
    sys.exit(1)

array_content = match.group(1)

# Parse individual item objects
items = []
pattern = r'\{\s*name:\s*"(.*?)",\s*price:\s*(\d+),\s*category:\s*"(.*?)",\s*subCategory:\s*"(.*?)",\s*isAvailable:\s*(true|false),\s*hasPrep:\s*(true|false),\s*stock:\s*(\d+),\s*imageUrl:\s*"(.*?)"\s*\}'
for m in re.finditer(pattern, array_content):
    name, price, category, subCategory, isAvailable, hasPrep, stock, imageUrl = m.groups()
    doc_id = make_doc_id(name)
    items.append((doc_id, {
        "name": name,
        "price": int(price),
        "category": category,
        "subCategory": subCategory,
        "isAvailable": isAvailable == "true",
        "hasPrep": hasPrep == "true",
        "stock": int(stock),
        "imageUrl": imageUrl,
    }))

print(f"Parsed {len(items)} items from seed.js.")

# Verify no duplicate IDs
ids = [doc_id for doc_id, _ in items]
duplicates = [doc_id for doc_id in ids if ids.count(doc_id) > 1]
if duplicates:
    print(f"WARNING: Duplicate document IDs detected: {set(duplicates)}")
    print("Fix the item names in seed.js so they produce unique slugs.")
    sys.exit(1)

# Print the stable ID mapping for reference
print("\nStable ID mapping (first 10):")
for doc_id, item in items[:10]:
    print(f"  {doc_id:40s} <- {item['name']}")
print(f"  ... and {len(items) - 10} more\n")

# Write to Menu collection in Firestore emulator
coll_ref = db.collection("Menu")

# Clear all existing documents first
print("Clearing Menu collection in emulator...")
docs = list(coll_ref.stream())
deleted = 0
for d in docs:
    d.reference.delete()
    deleted += 1
print(f"Deleted {deleted} existing document(s).")

# Write items using deterministic document IDs
print("Seeding Menu items with stable IDs...")
inserted = 0
for doc_id, item in items:
    coll_ref.document(doc_id).set(item)
    inserted += 1
    if inserted % 20 == 0:
        print(f"  Inserted {inserted}/{len(items)} items...")

print(f"\nSeeding completed successfully! Total: {inserted}")
print("IMPORTANT: Clear your browser's site data before testing.")
print("  Chrome: DevTools (F12) -> Application -> Storage -> Clear site data")
print("  This flushes the Firestore offline cache holding stale production IDs.")
