/**
 * seed.js — Firestore REST API seeder for Canteen App
 *
 * Uses the Firebase CLI's cached OAuth2 token to authenticate.
 * No service account key or gcloud installation required.
 *
 * Usage:  node seed.js
 */

import { UserRefreshClient } from "google-auth-library";

// ─── Config ───────────────────────────────────────────────────────────────────

const PROJECT_ID = "canteen-app-e1c8d";
const COLLECTION = "Menu";  // Flutter reads 'Menu' (capital M) — app_flow_screen.dart:30, admin_menu_screen.dart:71
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// Firebase CLI OAuth2 credentials (public client, stored locally after `firebase login`)
const FIREBASE_CLIENT_ID =
  "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
const FIREBASE_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";
const REFRESH_TOKEN =
  "1//0gEmjm_w5hDcBCgYIARAAGBASNwF-L9Irh-1sCEc6ZEJ47CL0rVeQpzBeJA1N3qHWiw6XqjY-21t1c_hKL5gwjPHvHRltdXk3zSA";

// ─── Auth ─────────────────────────────────────────────────────────────────────

async function getAccessToken() {
  const client = new UserRefreshClient(
    FIREBASE_CLIENT_ID,
    FIREBASE_CLIENT_SECRET,
    REFRESH_TOKEN
  );
  const { credentials } = await client.refreshAccessToken();
  return credentials.access_token;
}

// ─── Firestore REST helpers ───────────────────────────────────────────────────

/** Convert a plain JS object to a Firestore REST `fields` map */
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

/** GET all document names in the collection (handles pagination) */
async function listDocumentNames(token) {
  const names = [];
  let pageToken = null;

  do {
    const url =
      `${BASE_URL}/${COLLECTION}?pageSize=300&mask.fieldPaths=name` +
      (pageToken ? `&pageToken=${pageToken}` : "");

    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });

    if (!res.ok) {
      const text = await res.text();
      // 404 means collection is empty — that's fine
      if (res.status === 404) break;
      throw new Error(`List failed (${res.status}): ${text}`);
    }

    const body = await res.json();
    if (body.documents) {
      body.documents.forEach((d) => names.push(d.name));
    }
    pageToken = body.nextPageToken ?? null;
  } while (pageToken);

  return names;
}

/** DELETE a single document by full resource name */
async function deleteDocument(name, token) {
  const url = `https://firestore.googleapis.com/v1/${name}`;
  const res = await fetch(url, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok && res.status !== 404) {
    throw new Error(`Delete failed (${res.status}): ${await res.text()}`);
  }
}

/** POST a new document with auto-generated ID */
async function createDocument(item, token) {
  const url = `${BASE_URL}/${COLLECTION}`;
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

// ─── Menu Data ────────────────────────────────────────────────────────────────

const menuItems = [
  // ═══════════════════════════════════════════════════════════════
  //  BAKERY
  // ═══════════════════════════════════════════════════════════════

  // snacks
  { name: "Egg Puff",                    price: 30,  category: "bakery",      subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Veg Puff",                    price: 25,  category: "bakery",      subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Samosa Big",                  price: 25,  category: "bakery",      subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Samosa Small 4 Pieces",       price: 30,  category: "bakery",      subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Small Samosa Half Plate 2 Pieces", price: 15, category: "bakery", subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Cream Bun",                   price: 25,  category: "bakery",      subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Maska Bun",                   price: 40,  category: "bakery",      subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Dilpasand",                   price: 25,  category: "bakery",      subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Dilkhush",                    price: 25,  category: "bakery",      subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Love Bite",                   price: 20,  category: "bakery",      subCategory: "snacks",           isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },

  // packaged_snacks
  { name: "Oreo Biscuit",                price: 10,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Hide And Seek Biscuit",       price: 30,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Biscuit 10",                  price: 10,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Biscuit 35",                  price: 35,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Lays",                        price: 20,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Kurkure",                     price: 20,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Chips 20",                    price: 20,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Bingo 20",                    price: 20,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Bingo Tedhe Medhe",           price: 20,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Chips 30",                    price: 30,  category: "bakery",      subCategory: "packaged_snacks",  isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },

  // chocolates
  { name: "Chocolate Silk",              price: 10,  category: "bakery",      subCategory: "chocolates",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Snickers",                    price: 20,  category: "bakery",      subCategory: "chocolates",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Munch",                       price: 10,  category: "bakery",      subCategory: "chocolates",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "5 Star",                      price: 20,  category: "bakery",      subCategory: "chocolates",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Dairy Milk",                  price: 20,  category: "bakery",      subCategory: "chocolates",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Munch 5",                     price: 5,   category: "bakery",      subCategory: "chocolates",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },

  // ice_cream
  { name: "Ice Cream 10",                price: 10,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 18",                price: 18,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 20",                price: 20,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 22",                price: 22,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 25",                price: 25,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 30",                price: 30,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 35",                price: 35,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 40",                price: 40,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 45",                price: 45,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 50",                price: 50,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Ice Cream 70",                price: 70,  category: "bakery",      subCategory: "ice_cream",        isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },

  // pastries
  { name: "Pineapple Pastry",            price: 50,  category: "bakery",      subCategory: "pastries",         isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Black Forest Pastry",         price: 60,  category: "bakery",      subCategory: "pastries",         isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },

  // cold_drinks
  { name: "Badam Milk 200ml",            price: 40,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Water Bottle 1L",             price: 20,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Thums Up 200ml",              price: 20,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Pulpy Orange PET Bottle",     price: 25,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Diet Coke Can",               price: 40,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Maaza PET Bottle",            price: 20,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Maaza 10",                    price: 10,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Sprite PET Bottle",           price: 20,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Fanta PET Bottle",            price: 20,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Coca Cola 250ml",             price: 20,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Smooth 20",                   price: 20,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Appy Fizz",                   price: 40,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Mogu Mogu",                   price: 40,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Red Bull",                    price: 125, category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Appy Fizz Tin",               price: 40,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Monster",                     price: 125, category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "BRU Cold Coffee",             price: 60,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Campa 20",                    price: 20,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Jeera Soda",                  price: 10,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Butter Milk",                 price: 15,  category: "bakery",      subCategory: "cold_drinks",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },

  // ═══════════════════════════════════════════════════════════════
  //  BEVERAGES
  // ═══════════════════════════════════════════════════════════════

  // hot — Tea & Coffee are isNonQuantifiable in Flutter so stock=0 is fine; others need stock
  { name: "Tea",                         price: 20,  category: "beverages",   subCategory: "hot",              isAvailable: true, hasPrep: false, stock: 0,  imageUrl: "" },
  { name: "Coffee",                      price: 25,  category: "beverages",   subCategory: "hot",              isAvailable: true, hasPrep: false, stock: 0,  imageUrl: "" },
  { name: "Milk",                        price: 20,  category: "beverages",   subCategory: "hot",              isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Horlicks",                    price: 25,  category: "beverages",   subCategory: "hot",              isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Boost",                       price: 25,  category: "beverages",   subCategory: "hot",              isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Lemon Tea",                   price: 30,  category: "beverages",   subCategory: "hot",              isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Green Tea",                   price: 30,  category: "beverages",   subCategory: "hot",              isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Black Coffee",                price: 25,  category: "beverages",   subCategory: "hot",              isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },

  // fresh_juice
  { name: "Mosambi Juice",               price: 40,  category: "beverages",   subCategory: "fresh_juice",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Pineapple Juice",             price: 40,  category: "beverages",   subCategory: "fresh_juice",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Grape Juice",                 price: 40,  category: "beverages",   subCategory: "fresh_juice",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Watermelon Juice",            price: 40,  category: "beverages",   subCategory: "fresh_juice",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Muskmelon Juice",             price: 40,  category: "beverages",   subCategory: "fresh_juice",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Mango Juice",                 price: 40,  category: "beverages",   subCategory: "fresh_juice",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Sapota Juice",                price: 40,  category: "beverages",   subCategory: "fresh_juice",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Cut Fruit Bowl",              price: 40,  category: "beverages",   subCategory: "fresh_juice",      isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },

  // milkshakes
  { name: "Mango Milkshake",             price: 50,  category: "beverages",   subCategory: "milkshakes",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Oreo Milkshake",              price: 50,  category: "beverages",   subCategory: "milkshakes",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Strawberry Milkshake",        price: 50,  category: "beverages",   subCategory: "milkshakes",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },
  { name: "Chocolate Milkshake",         price: 50,  category: "beverages",   subCategory: "milkshakes",       isAvailable: true, hasPrep: false, stock: 50, imageUrl: "" },

  // ═══════════════════════════════════════════════════════════════
  //  MESS
  // ═══════════════════════════════════════════════════════════════

  // tiffin — mess is isNonQuantifiable, stock is ignored; set 0 for clarity
  { name: "Idly",                        price: 45,  category: "mess",        subCategory: "tiffin",           isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Vada",                        price: 45,  category: "mess",        subCategory: "tiffin",           isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Poori",                       price: 45,  category: "mess",        subCategory: "tiffin",           isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Plain Dosa",                  price: 35,  category: "mess",        subCategory: "tiffin",           isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Masala Dosa",                 price: 45,  category: "mess",        subCategory: "tiffin",           isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Onion Dosa",                  price: 45,  category: "mess",        subCategory: "tiffin",           isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },

  // lunch
  { name: "Veg Noodles",                 price: 75,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Veg Manchurian",              price: 80,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Paneer Fried Rice",           price: 110, category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Schezwan Noodles",            price: 85,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Veg Fried Rice",              price: 90,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Manchurian Noodles",          price: 85,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Manchurian Fried Rice",       price: 100, category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Schezwan Fried Rice",         price: 90,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Schezwan Manchurian",         price: 85,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Jeera Rice",                  price: 85,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Veg Meals",                   price: 120, category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Parota with Kurma",           price: 55,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Curd",                        price: 30,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Curry",                       price: 30,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Special Meals",               price: 120, category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Curd Rice",                   price: 60,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },
  { name: "Sweet",                       price: 35,  category: "mess",        subCategory: "lunch",            isAvailable: true, hasPrep: true,  stock: 0,  imageUrl: "" },

  // ═══════════════════════════════════════════════════════════════
  //  CONTINENTAL
  // ═══════════════════════════════════════════════════════════════

  // sandwiches — continental is NOT isNonQuantifiable, needs stock
  { name: "Veg Grilled Sandwich",        price: 59,  category: "continental", subCategory: "sandwiches",       isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Veg Cheese Sandwich",         price: 89,  category: "continental", subCategory: "sandwiches",       isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Tandoori Veg Burger Sandwich",price: 89,  category: "continental", subCategory: "sandwiches",       isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Paneer Cheese Sandwich",      price: 99,  category: "continental", subCategory: "sandwiches",       isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Chipotle Paneer Cheese Sandwich", price: 99, category: "continental", subCategory: "sandwiches",   isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Tandoori Paneer Cheese Sandwich", price: 99, category: "continental", subCategory: "sandwiches",   isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },

  // burgers
  { name: "Classic Veg Burger",          price: 69,  category: "continental", subCategory: "burgers",          isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Veg Cheese Burger",           price: 89,  category: "continental", subCategory: "burgers",          isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Tandoori Veg Burger",         price: 99,  category: "continental", subCategory: "burgers",          isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Chipotle Cheese Burger",      price: 99,  category: "continental", subCategory: "burgers",          isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },

  // fries_and_starters
  { name: "Salted Fries",                price: 59,  category: "continental", subCategory: "fries_and_starters", isAvailable: true, hasPrep: true, stock: 50, imageUrl: "" },
  { name: "Peri Peri Fries",             price: 69,  category: "continental", subCategory: "fries_and_starters", isAvailable: true, hasPrep: true, stock: 50, imageUrl: "" },
  { name: "Veg Cheese Nuggets 6 Pieces", price: 79,  category: "continental", subCategory: "fries_and_starters", isAvailable: true, hasPrep: true, stock: 50, imageUrl: "" },
  { name: "Chilli Potato Pops 12 Pieces",price: 79,  category: "continental", subCategory: "fries_and_starters", isAvailable: true, hasPrep: true, stock: 50, imageUrl: "" },
  { name: "Veggie Finger 6 Pieces",      price: 89,  category: "continental", subCategory: "fries_and_starters", isAvailable: true, hasPrep: true, stock: 50, imageUrl: "" },
  { name: "Veg Cheese Balls 6 Pieces",   price: 89,  category: "continental", subCategory: "fries_and_starters", isAvailable: true, hasPrep: true, stock: 50, imageUrl: "" },

  // pizzas
  { name: "Margherita Pizza",            price: 109, category: "continental", subCategory: "pizzas",           isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Garden Fresh Pizza",          price: 129, category: "continental", subCategory: "pizzas",           isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Paneer Tikka Pizza",          price: 159, category: "continental", subCategory: "pizzas",           isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "BBQ Paneer Pizza",            price: 179, category: "continental", subCategory: "pizzas",           isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Tandoori Paneer Pizza",       price: 179, category: "continental", subCategory: "pizzas",           isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Cheese Corn Pizza",           price: 129, category: "continental", subCategory: "pizzas",           isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Tangy Tomato Pizza",          price: 129, category: "continental", subCategory: "pizzas",           isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },

  // hot_dogs
  { name: "Veg Hot Dog",                 price: 60,  category: "continental", subCategory: "hot_dogs",         isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
  { name: "Paneer Hot Dog",              price: 70,  category: "continental", subCategory: "hot_dogs",         isAvailable: true, hasPrep: true,  stock: 50, imageUrl: "" },
];

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log("\n🚀 Starting Firestore menu seed (via REST API)…");
  console.log(`   Project    : ${PROJECT_ID}`);
  console.log(`   Collection : ${COLLECTION}`);
  console.log(`   Items      : ${menuItems.length} total\n`);

  console.log("🔑 Obtaining access token…");
  const token = await getAccessToken();
  console.log("   ✅ Token obtained.\n");

  // ── Step 1: Clear existing documents ──────────────────────────────────────
  console.log("Step 1 ▸ Listing existing documents…");
  const existingNames = await listDocumentNames(token);
  console.log(`   Found ${existingNames.length} existing document(s).`);

  if (existingNames.length > 0) {
    console.log("   Deleting…");
    let deleted = 0;
    for (const name of existingNames) {
      await deleteDocument(name, token);
      deleted++;
      if (deleted % 20 === 0) {
        console.log(`   🗑  ${deleted} / ${existingNames.length} deleted…`);
      }
    }
    console.log(`   ✅ Deleted all ${existingNames.length} document(s).\n`);
  } else {
    console.log("   ℹ️  Collection is already empty.\n");
  }

  // ── Step 2: Insert new documents ──────────────────────────────────────────
  console.log("Step 2 ▸ Inserting menu items…");
  let inserted = 0;
  for (const item of menuItems) {
    await createDocument(item, token);
    inserted++;
    if (inserted % 20 === 0) {
      console.log(`   📝 ${inserted} / ${menuItems.length} inserted…`);
    }
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  console.log(`\n✅ Done! Total documents inserted: ${inserted}`);

  const breakdown = menuItems.reduce((acc, item) => {
    acc[item.category] = (acc[item.category] || 0) + 1;
    return acc;
  }, {});

  console.log("\n📊 Breakdown by category:");
  Object.entries(breakdown).forEach(([cat, n]) =>
    console.log(`   ${cat.padEnd(14)}: ${n} items`)
  );

  const subBreakdown = menuItems.reduce((acc, item) => {
    const key = `${item.category}/${item.subCategory}`;
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});

  console.log("\n📋 Breakdown by subCategory:");
  Object.entries(subBreakdown).forEach(([key, n]) =>
    console.log(`   ${key.padEnd(36)}: ${n} items`)
  );
}

main().catch((err) => {
  console.error("\n❌ Seed failed:", err.message ?? err);
  process.exit(1);
});
