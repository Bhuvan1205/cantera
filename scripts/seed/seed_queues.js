/**
 * seed_queues.js
 *
 * Populates the `queues` top-level Firestore collection with one document
 * per mess item.  Each document acts as the real-time queue for that item
 * and holds the avg_prep_time_mins used for wait-time estimation.
 *
 * Run: node seed_queues.js
 * Requires: npm install (google-auth-library is already in package.json)
 */

import { UserRefreshClient } from 'google-auth-library';

// ── Auth credentials (same as seed.js) ───────────────────────────────────────
const CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const REFRESH_TOKEN =
  '1//0gEmjm_w5hDcBCgYIARAAGBASNwF-L9Irh-1sCEc6ZEJ47CL0rVeQpzBeJA1N3qHWiw6XqjY-21t1c_hKL5gwjPHvHRltdXk3zSA';
const PROJECT_ID = 'canteen-app-e1c8d';

const BASE =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ── Queue documents to create ─────────────────────────────────────────────────
// Document ID = item_name (exact match to what the Flutter app stores in cart)
// avg_prep_time_mins = default cook time for wait-time estimation
const QUEUE_ITEMS = [
  // Tiffin
  { item_name: 'Plain Dosa',          avg_prep_time_mins: 3  },
  { item_name: 'Masala Dosa',         avg_prep_time_mins: 4  },
  { item_name: 'Onion Dosa',          avg_prep_time_mins: 4  },
  { item_name: 'Idly',                avg_prep_time_mins: 6  },
  { item_name: 'Vada',                avg_prep_time_mins: 5  },
  { item_name: 'Poori',               avg_prep_time_mins: 4  },
  // Lunch — cooked items
  { item_name: 'Veg Noodles',         avg_prep_time_mins: 7  },
  { item_name: 'Veg Manchurian',      avg_prep_time_mins: 8  },
  { item_name: 'Paneer Fried Rice',   avg_prep_time_mins: 9  },
  { item_name: 'Schezwan Noodles',    avg_prep_time_mins: 8  },
  { item_name: 'Veg Fried Rice',      avg_prep_time_mins: 8  },
  { item_name: 'Manchurian Noodles',  avg_prep_time_mins: 9  },
  { item_name: 'Manchurian Fried Rice', avg_prep_time_mins: 9 },
  { item_name: 'Schezwan Fried Rice', avg_prep_time_mins: 8  },
  { item_name: 'Schezwan Manchurian', avg_prep_time_mins: 9  },
  { item_name: 'Jeera Rice',          avg_prep_time_mins: 4  },
  { item_name: 'Veg Meals',           avg_prep_time_mins: 5  },
  { item_name: 'Special Meals',       avg_prep_time_mins: 6  },
  { item_name: 'Parota with Kurma',   avg_prep_time_mins: 5  },
  { item_name: 'Curd Rice',           avg_prep_time_mins: 3  },
  // Lunch — pre-made (minimal wait)
  { item_name: 'Curd',                avg_prep_time_mins: 1  },
  { item_name: 'Curry',               avg_prep_time_mins: 1  },
  { item_name: 'Sweet',               avg_prep_time_mins: 1  },
];

// ── Helpers ───────────────────────────────────────────────────────────────────

function toFirestoreDoc(item) {
  return {
    fields: {
      item_name:            { stringValue: item.item_name },
      avg_prep_time_mins:   { integerValue: String(item.avg_prep_time_mins) },
      queue:                { arrayValue: { values: [] } },      // empty — no active orders
      total_prep_units_ahead: { doubleValue: 0 },
    },
  };
}

async function upsertDoc(token, docId, body) {
  const url = `${BASE}/queues/${encodeURIComponent(docId)}`;
  const res = await fetch(url, {
    method: 'PATCH',  // PATCH = createOrUpdate
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

// ── Main ──────────────────────────────────────────────────────────────────────

console.log('🚀  Seeding queues collection…');
console.log(`   Project    : ${PROJECT_ID}`);
console.log(`   Collection : queues`);
console.log(`   Items      : ${QUEUE_ITEMS.length} mess queue documents\n`);

console.log('🔑  Obtaining access token…');
const client = new UserRefreshClient(CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN);
const { credentials } = await client.refreshAccessToken();
const token = credentials.access_token;
console.log('   ✅  Token obtained.\n');

console.log('📝  Writing queue documents…');
let count = 0;
for (const item of QUEUE_ITEMS) {
  await upsertDoc(token, item.item_name, toFirestoreDoc(item));
  count++;
  process.stdout.write(`\r   ${count} / ${QUEUE_ITEMS.length} written…`);
}

console.log(`\n\n✅  Done! ${count} queue documents written to \`queues\` collection.\n`);
console.log('📋  Queue documents created:');
for (const item of QUEUE_ITEMS) {
  console.log(`   ${item.item_name.padEnd(26)} avg ${item.avg_prep_time_mins} min`);
}
console.log('');
