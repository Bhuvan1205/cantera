// Test script for CanteenBuzz aggregation logic

function aggregateOrders(ordersSnap) {
  const frequencies = {};

  // Emulate the .limit(30) behavior if more than 30 are passed, although 
  // the actual db query would handle the limit. We just take up to 30 for the test.
  const limitedOrders = ordersSnap.slice(0, 30);

  limitedOrders.forEach((doc) => {
    const data = doc.data();
    const items = data.items || [];
    items.forEach((item) => {
      if (item.name) {
        const name = item.name.toLowerCase().trim();
        const qty = parseInt(item.quantity, 10) || 1;
        frequencies[name] = (frequencies[name] || 0) + qty;
      }
    });
  });

  return Object.entries(frequencies)
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 5)
    .map(([name, count]) => ({ name, count }));
}

// ---------------------------------------------------------
// TEST CASES
// ---------------------------------------------------------

let allPassed = true;
function assert(name, condition) {
  if (condition) {
    console.log(`[PASS] ${name}`);
  } else {
    console.error(`[FAIL] ${name}`);
    allPassed = false;
  }
}

// Test 1 — Normal Orders & Sorting
const snap1 = [
  { data: () => ({ items: [{ name: "Chicken Biryani", quantity: 15 }] }) },
  { data: () => ({ items: [{ name: "Tea", quantity: 11 }] }) },
  { data: () => ({ items: [{ name: "Burger", quantity: 8 }] }) }
];
const res1 = aggregateOrders(snap1);
assert("Test 1: Normal Orders", res1[0].name === "chicken biryani" && res1[0].count === 15 && res1.length === 3);

// Test 2 — Quantity Aggregation
const snap2 = [
  { data: () => ({ items: [{ name: "Tea", quantity: 5 }] }) },
  { data: () => ({ items: [{ name: "tea", quantity: 2 }] }) } // case insensitivity
];
const res2 = aggregateOrders(snap2);
assert("Test 2: Quantity", res2[0].name === "tea" && res2[0].count === 7);

// Test 3 — Empty Orders
const snap3 = [
  { data: () => ({ items: [] }) },
  { data: () => ({}) } // Missing items array
];
const res3 = aggregateOrders(snap3);
assert("Test 3: Empty Orders", res3.length === 0);

// Test 4 — Missing/Invalid Item Data
const snap4 = [
  { data: () => ({ items: [{ name: "InvalidQty", quantity: "abc" }] }) }, // Should default to 1
  { data: () => ({ items: [{ quantity: 5 }] }) }, // Missing name (should be skipped)
];
const res4 = aggregateOrders(snap4);
assert("Test 4: Invalid/Missing Data", res4[0].name === "invalidqty" && res4[0].count === 1 && res4.length === 1);

// Test 5 — More Than 30 Orders
const snap5 = [];
for (let i = 0; i < 35; i++) {
  snap5.push({ data: () => ({ items: [{ name: `Item ${i}`, quantity: 1 }] }) });
}
const res5 = aggregateOrders(snap5);
// The logic will only take the first 30 (limit 30 query) and return top 5
assert("Test 5: More Than 30 Orders", res5.length === 5);

if (allPassed) {
  console.log("ALL TESTS PASSED");
} else {
  console.error("SOME TESTS FAILED");
  process.exit(1);
}
