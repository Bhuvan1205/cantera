/**
 * seed_queues.js
 *
 * Populates the `queues` top-level Firestore collection with one document
 * per mess item.  Each document acts as the real-time queue for that item
 * and holds the avg_prep_time_mins used for wait-time estimation.
 *
 * Reads from DataSets/menu_dataset.csv
 *
 * Run: node seed_queues.js
 */

import { UserRefreshClient } from 'google-auth-library';
import fs from 'fs';
import csv from 'csv-parser';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const REFRESH_TOKEN = '1//0gEmjm_w5hDcBCgYIARAAGBASNwF-L9Irh-1sCEc6ZEJ47CL0rVeQpzBeJA1N3qHWiw6XqjY-21t1c_hKL5gwjPHvHRltdXk3zSA';
const PROJECT_ID = 'canteen-app-e1c8d';

const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

const DEFAULT_PREP_TIMES = {
  "Plain Dosa": 3,
  "Masala Dosa": 4,
  "Onion Dosa": 4,
  "Idly": 6,
  "Vada": 5,
  "Poori": 4,
  "Veg Noodles": 7,
  "Veg Manchuria": 8, // from CSV
  "Paneer Fried Rice": 9,
  "Schezwan Noodles": 8,
  "Veg Fried Rice": 8,
  "Manchuria Noodles": 9, // from CSV
  "Manchuria Fried Rice": 9, // from CSV
  "Shezwan Fried Rice": 8, // from CSV
  "Shezwan Manchuria": 9, // from CSV
  "Jeera Rice": 4,
  "Veg Meals": 5,
  "Special Meals": 6,
  "Parota with Kurma": 5,
  "Curd Rice": 3,
  "Curd": 1,
  "Curry": 1,
  "Sweet": 1,
};

function getPrepTime(name) {
  return DEFAULT_PREP_TIMES[name] ?? 5; // default 5 mins for unknown like pizzas/burgers
}

function toFirestoreDoc(item) {
  return {
    fields: {
      item_name:            { stringValue: item.item_name },
      avg_prep_time_mins:   { integerValue: String(item.avg_prep_time_mins) },
      queue:                { arrayValue: { values: [] } },
      total_prep_units_ahead: { doubleValue: 0 },
    },
  };
}

async function upsertDoc(token, docId, body) {
  const url = `${BASE}/queues/${encodeURIComponent(docId)}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Failed to upsert "${docId}": ${err}`);
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
  console.log('🚀  Seeding queues collection…');
  console.log(`   Project    : ${PROJECT_ID}`);
  console.log(`   Collection : queues\n`);

  console.log('🔑  Obtaining access token…');
  const client = new UserRefreshClient(CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN);
  const { credentials } = await client.refreshAccessToken();
  const token = credentials.access_token;
  console.log('   ✅  Token obtained.\n');

  console.log("📝 Parsing CSV...");
  const csvPath = path.join(__dirname, "..", "..", "DataSets", "menu_dataset.csv");
  const records = await parseCSV(csvPath);
  
  const messItems = records
    .filter(r => r.category.toLowerCase().trim() === 'mess')
    .map(r => ({
      item_name: r.item_name.trim(),
      avg_prep_time_mins: getPrepTime(r.item_name.trim())
    }));
    
  console.log(`   Found ${messItems.length} mess queue documents to create.`);

  console.log('\n📝  Writing queue documents…');
  let count = 0;
  for (const item of messItems) {
    await upsertDoc(token, item.item_name, toFirestoreDoc(item));
    count++;
    process.stdout.write(`\r   ${count} / ${messItems.length} written…`);
  }

  console.log(`\n\n✅  Done! ${count} queue documents written to \`queues\` collection.\n`);
}

main().catch(err => {
  console.error("\n❌ Seeding queues failed:", err.message ?? err);
  process.exit(1);
});
