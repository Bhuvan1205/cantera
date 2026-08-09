# Firestore Database Schema

This document defines the canonical collections, fields, data types, and security boundaries for the Cantora Firestore database.

---

## 1. `Users` Collection
Document ID: `userId` (Firebase Auth UID)

```json
{
  "name": "string",
  "email": "string",
  "phone": "string",
  "role": "string",              // "customer" | "staff" | "admin"
  "pickupPin": "string",         // 4-digit PIN (e.g. "1234")
  "pinLastChanged": "timestamp", // Timestamp of last PIN rotation
  "createdAt": "timestamp"
}
```
- **Rules:** Read allowed for document owner or admin. Write DENIED for all clients (managed via FastAPI).

---

## 2. `Menu` Collection
Document ID: `itemId` (e.g. "item_01" or generated)

```json
{
  "name": "string",
  "category": "string",          // "bakery" | "beverages" | "continental" | "mess"
  "price": "number",             // Price in INR (e.g. 50.0)
  "stock": "number",             // Available inventory units
  "is_available": "boolean",     // Master availability flag
  "image_url": "string",
  "prep_time_minutes": "number", // Base prep time for queue calculations
  "last_updated": "timestamp"
}
```
- **Rules:** Read allowed for authenticated users. Write DENIED for all clients.

---

## 3. `Orders` Collection
Document ID: `orderId` (UUID string)

```json
{
  "userId": "string",
  "userName": "string",
  "totalPrice": "number",
  "paymentMethod": "string",     // "wallet" | "directPayment"
  "status": "string",            // "placed" | "preparing" | "ready_for_pickup" | "delivered" | "cancelled" | "refund_pending"
  "overall_status": "string",
  "createdAt": "timestamp",
  "categoryTokens": {
    "bakery": { "tokenId": "T101", "status": "placed" },
    "mess": { "tokenId": "T102", "status": "preparing" }
  },
  "items": [
    {
      "itemId": "string",
      "name": "string",
      "price": "number",
      "quantity": "number",
      "category": "string"
    }
  ]
}
```

### `Orders/{orderId}/tokens` Subcollection
Document ID: `tokenId` (e.g. "T101")

```json
{
  "tokenId": "string",
  "counter": "string",           // "bakery" | "beverages" | "continental" | "mess"
  "token_status": "string",      // "placed" | "preparing" | "ready_for_pickup" | "delivered"
  "qr_valid": "boolean",
  "otp": "string",               // 4-digit OTP for mess pickup
  "queue_name": "string",        // "mess" if applicable
  "items": ["array of item sub-objects"],
  "updated_at": "timestamp"
}
```
- **Rules:** Read allowed for order owner, staff, and admin. Write DENIED for all clients.

---

## 4. `queues` Collection
Document ID: `queueName` (e.g. "mess")

```json
{
  "active_count": "number",
  "estimated_wait_time": "number",
  "queue": [
    {
      "orderId": "string",
      "tokenId": "string",
      "userId": "string",
      "itemName": "string",
      "quantity": "number",
      "status": "string",        // "waiting" | "preparing"
      "prep_units": "number",
      "joined_at": "timestamp",
      "prep_start_time": "timestamp"
    }
  ]
}
```
- **Rules:** Read allowed for authenticated users. Write DENIED for all clients.

---

## 5. `wallets` Collection
Document ID: `userId` (Firebase Auth UID)

```json
{
  "balance": "number",           // Current wallet balance in INR
  "total_added": "number",       // Cumulative lifetime deposits
  "total_spent": "number",       // Cumulative lifetime purchases
  "created_at": "timestamp",
  "last_updated": "timestamp",
  "last_order_id": "string"
}
```
- **Rules:** Read allowed for owner or admin. Write DENIED for all clients.

---

## 6. `wallet_transactions` Collection
Document ID: Generated transaction ID or order ID

```json
{
  "user_uid": "string",
  "type": "string",              // "deposit" | "purchase" | "refund" | "adjustment"
  "amount": "number",            // Transaction amount in INR
  "status": "string",            // "success" | "failed" | "pending"
  "description": "string",
  "order_id": "string",          // Nullable
  "initiated_by": "string",      // "user:<uid>" | "admin:<uid>" | "system"
  "timestamp": "timestamp",
  "balance_after": "number",
  "reference_type": "string",    // "order" | "pending_deposit" | "refund_request" | "adjustment"
  "reference_id": "string"
}
```
- **Rules:** Read allowed for transaction owner or admin. Write DENIED for all clients.

---

## 7. `pending_deposits` Collection
Document ID: Generated deposit ID

```json
{
  "user_uid": "string",
  "amount": "number",
  "razorpay_payment_id": "string",
  "razorpay_order_id": "string",
  "razorpay_signature": "string",
  "gateway": "string",           // "razorpay" | "mock"
  "status": "string",            // "awaiting_review" | "approved" | "rejected"
  "created_at": "timestamp",
  "reviewed_at": "timestamp",
  "reviewed_by": "string",
  "rejection_reason": "string"
}
```
- **Rules:** Read allowed for deposit owner or admin. Write DENIED for all clients.

---

## 8. `refund_requests` Collection
Document ID: Generated request ID

```json
{
  "user_uid": "string",
  "order_id": "string",
  "amount": "number",
  "status": "string",            // "refund_requested" | "refund_under_review" | "approved" | "credited" | "rejected"
  "reason": "string",
  "created_at": "timestamp",
  "resolved_at": "timestamp",
  "resolved_by": "string",
  "rejection_reason": "string"
}
```
- **Rules:** Read allowed for request owner or admin. Write DENIED for all clients.
