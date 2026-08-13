/**
 * ADR-001 Phase 3 – Firestore Security Rules Tests
 *
 * Tests run against the Firebase Emulator Suite.
 * Each collection is tested for:
 *   - Unauthenticated access → DENY
 *   - Authenticated customer read (own data) → ALLOW
 *   - Authenticated customer read (other's data) → DENY
 *   - Authenticated customer write (any) → DENY  ← critical ADR-001 check
 *   - Staff/admin read → ALLOW where applicable
 *   - Staff/admin write → DENY  ← critical ADR-001 check
 *
 * The Firebase Admin SDK bypasses rules — not tested here.
 * Backend writes are simulated by seeding data via Admin SDK in beforeAll.
 */

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { resolve } = require('path');

const PROJECT_ID = 'canteen-app-e1c8d';
const RULES_PATH = resolve(__dirname, '../../firestore.rules');

let testEnv;

// ── Test identity tokens ────────────────────────────────────────────────────
const CUSTOMER_UID  = 'customer_uid_001';
const OTHER_UID     = 'customer_uid_002';
const STAFF_UID     = 'staff_uid_001';
const ADMIN_UID     = 'admin_uid_001';

function customerDb()  { return testEnv.authenticatedContext(CUSTOMER_UID, { role: 'customer' }).firestore(); }
function otherDb()     { return testEnv.authenticatedContext(OTHER_UID,    { role: 'customer' }).firestore(); }
function staffDb()     { return testEnv.authenticatedContext(STAFF_UID,    { role: 'staff' }).firestore(); }
function adminDb()     { return testEnv.authenticatedContext(ADMIN_UID,    { role: 'admin', admin: true }).firestore(); }
function anonDb()      { return testEnv.unauthenticatedContext().firestore(); }

// ── Seed data (written via Admin SDK, bypasses rules) ──────────────────────
beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 9090,
    },
  });

  // Seed: Users
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.collection('Users').doc(CUSTOMER_UID).set({ userId: CUSTOMER_UID, name: 'Alice', isAdmin: false });
    await db.collection('Users').doc(OTHER_UID).set({ userId: OTHER_UID, name: 'Bob', isAdmin: false });
    await db.collection('Users').doc(ADMIN_UID).set({ userId: ADMIN_UID, name: 'Admin', isAdmin: true });

    // Seed: Menu
    await db.collection('Menu').doc('item_idly').set({ name: 'Idly', price: 40, stock: 20, category: 'Mess', isAvailable: true });

    // Seed: Orders
    await db.collection('Orders').doc('order_001').set({ userId: CUSTOMER_UID, total: 80, status: 'placed', overall_status: 'active' });
    await db.collection('Orders').doc('order_002').set({ userId: OTHER_UID, total: 40, status: 'placed', overall_status: 'active' });

    // Seed: Tokens subcollection
    await db.collection('Orders').doc('order_001').collection('tokens').doc('token_001').set({
      counter: 'mess', token_status: 'placed', qr_valid: true, token_id: 'token_001'
    });

    // Seed: Queues
    await db.collection('queues').doc('Idly').set({ item_name: 'Idly', queue: [], total_prep_units_ahead: 0 });

    // Seed: Wallets
    await db.collection('wallets').doc(CUSTOMER_UID).set({ balance: 500, total_added: 500, total_spent: 0 });
    await db.collection('wallets').doc(OTHER_UID).set({ balance: 200, total_added: 200, total_spent: 0 });

    // Seed: Wallet transactions
    await db.collection('wallet_transactions').doc('tx_001').set({ user_uid: CUSTOMER_UID, amount: 80, type: 'purchase' });
    await db.collection('wallet_transactions').doc('tx_002').set({ user_uid: OTHER_UID, amount: 40, type: 'purchase' });

    // Seed: Pending deposits
    await db.collection('pending_deposits').doc('dep_001').set({ user_uid: CUSTOMER_UID, amount: 100, status: 'awaiting_review' });
    await db.collection('pending_deposits').doc('dep_002').set({ user_uid: OTHER_UID, amount: 50, status: 'awaiting_review' });

    // Seed: Refund requests
    await db.collection('refund_requests').doc('ref_001').set({ user_uid: CUSTOMER_UID, order_id: 'order_001', status: 'refund_requested' });
    await db.collection('refund_requests').doc('ref_002').set({ user_uid: OTHER_UID, order_id: 'order_002', status: 'refund_requested' });
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

// ════════════════════════════════════════════════════════════════════════════
// 1. UNAUTHENTICATED — all operations denied
// ════════════════════════════════════════════════════════════════════════════
describe('Unauthenticated access — deny all', () => {
  test('cannot read Users', async () => {
    await assertFails(anonDb().collection('Users').doc(CUSTOMER_UID).get());
  });
  test('cannot write Users', async () => {
    await assertFails(anonDb().collection('Users').doc('new_user').set({ name: 'X' }));
  });
  test('cannot read Menu', async () => {
    await assertFails(anonDb().collection('Menu').doc('item_idly').get());
  });
  test('cannot read Orders', async () => {
    await assertFails(anonDb().collection('Orders').doc('order_001').get());
  });
  test('cannot read queues', async () => {
    await assertFails(anonDb().collection('queues').doc('Idly').get());
  });
  test('cannot read wallets', async () => {
    await assertFails(anonDb().collection('wallets').doc(CUSTOMER_UID).get());
  });
  test('cannot read wallet_transactions', async () => {
    await assertFails(anonDb().collection('wallet_transactions').doc('tx_001').get());
  });
  test('cannot read pending_deposits', async () => {
    await assertFails(anonDb().collection('pending_deposits').doc('dep_001').get());
  });
  test('cannot read refund_requests', async () => {
    await assertFails(anonDb().collection('refund_requests').doc('ref_001').get());
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 2. USERS collection
// ════════════════════════════════════════════════════════════════════════════
describe('Users collection', () => {
  // Reads
  test('[ALLOW] customer can read own profile', async () => {
    await assertSucceeds(customerDb().collection('Users').doc(CUSTOMER_UID).get());
  });
  test('[DENY] customer cannot read another user profile', async () => {
    await assertFails(customerDb().collection('Users').doc(OTHER_UID).get());
  });
  test('[ALLOW] admin can read any profile', async () => {
    await assertSucceeds(adminDb().collection('Users').doc(CUSTOMER_UID).get());
  });

  // Writes — ALL DENIED (ADR-001)
  test('[DENY] customer cannot create own profile directly', async () => {
    await assertFails(customerDb().collection('Users').doc(CUSTOMER_UID).set({
      name: 'Alice', isAdmin: false
    }));
  });
  test('[DENY] customer cannot update own profile directly', async () => {
    await assertFails(customerDb().collection('Users').doc(CUSTOMER_UID).update({
      name: 'Alice Updated'
    }));
  });
  test('[DENY] customer cannot update pickup PIN directly', async () => {
    await assertFails(customerDb().collection('Users').doc(CUSTOMER_UID).update({
      pickupPin: '9999'
    }));
  });
  test('[DENY] staff cannot write user profiles', async () => {
    await assertFails(staffDb().collection('Users').doc(CUSTOMER_UID).update({
      name: 'Hacked'
    }));
  });
  test('[DENY] admin cannot write user profiles via client SDK', async () => {
    await assertFails(adminDb().collection('Users').doc(CUSTOMER_UID).update({
      isAdmin: true
    }));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 3. MENU collection
// ════════════════════════════════════════════════════════════════════════════
describe('Menu collection', () => {
  test('[ALLOW] customer can read menu items', async () => {
    await assertSucceeds(customerDb().collection('Menu').doc('item_idly').get());
  });
  test('[ALLOW] customer can list menu', async () => {
    await assertSucceeds(customerDb().collection('Menu').get());
  });

  // Writes — ALL DENIED (ADR-001)
  test('[DENY] customer cannot create menu items', async () => {
    await assertFails(customerDb().collection('Menu').add({ name: 'Hack', price: 1, stock: 100 }));
  });
  test('[DENY] customer cannot update stock', async () => {
    await assertFails(customerDb().collection('Menu').doc('item_idly').update({ stock: 0 }));
  });
  test('[DENY] staff cannot update menu via client SDK', async () => {
    await assertFails(staffDb().collection('Menu').doc('item_idly').update({ stock: 15 }));
  });
  test('[DENY] admin cannot update menu via client SDK', async () => {
    await assertFails(adminDb().collection('Menu').doc('item_idly').update({ price: 999 }));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 4. ORDERS collection
// ════════════════════════════════════════════════════════════════════════════
describe('Orders collection', () => {
  // Reads
  test('[ALLOW] customer can read own order', async () => {
    await assertSucceeds(customerDb().collection('Orders').doc('order_001').get());
  });
  test('[DENY] customer cannot read another customer\'s order', async () => {
    await assertFails(customerDb().collection('Orders').doc('order_002').get());
  });
  test('[ALLOW] staff can read any order', async () => {
    await assertSucceeds(staffDb().collection('Orders').doc('order_001').get());
    await assertSucceeds(staffDb().collection('Orders').doc('order_002').get());
  });

  // Writes — ALL DENIED (ADR-001)
  test('[DENY] customer cannot place order directly', async () => {
    await assertFails(customerDb().collection('Orders').add({
      userId: CUSTOMER_UID, total: 100, status: 'placed', overall_status: 'active'
    }));
  });
  test('[DENY] customer cannot update own order status', async () => {
    await assertFails(customerDb().collection('Orders').doc('order_001').update({
      status: 'delivered'
    }));
  });
  test('[DENY] customer cannot set order to refund_pending directly', async () => {
    await assertFails(customerDb().collection('Orders').doc('order_001').update({
      status: 'refund_pending'
    }));
  });
  test('[DENY] staff cannot update order status via client SDK', async () => {
    await assertFails(staffDb().collection('Orders').doc('order_001').update({
      status: 'delivered'
    }));
  });
  test('[DENY] admin cannot update order via client SDK', async () => {
    await assertFails(adminDb().collection('Orders').doc('order_001').update({
      status: 'cancelled'
    }));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 5. ORDERS/TOKENS subcollection
// ════════════════════════════════════════════════════════════════════════════
describe('Orders/tokens subcollection', () => {
  // Reads
  test('[ALLOW] order owner can read own tokens', async () => {
    await assertSucceeds(
      customerDb().collection('Orders').doc('order_001').collection('tokens').doc('token_001').get()
    );
  });
  test('[DENY] other customer cannot read tokens', async () => {
    await assertFails(
      otherDb().collection('Orders').doc('order_001').collection('tokens').doc('token_001').get()
    );
  });
  test('[ALLOW] staff can read any token', async () => {
    await assertSucceeds(
      staffDb().collection('Orders').doc('order_001').collection('tokens').doc('token_001').get()
    );
  });

  // Writes — ALL DENIED (ADR-001)
  test('[DENY] customer cannot create tokens directly', async () => {
    await assertFails(
      customerDb().collection('Orders').doc('order_001').collection('tokens').add({
        counter: 'bakery', token_status: 'placed', qr_valid: true
      })
    );
  });
  test('[DENY] staff cannot update token status via client SDK', async () => {
    await assertFails(
      staffDb().collection('Orders').doc('order_001').collection('tokens').doc('token_001').update({
        token_status: 'delivered', qr_valid: false
      })
    );
  });
  test('[DENY] admin cannot update token via client SDK', async () => {
    await assertFails(
      adminDb().collection('Orders').doc('order_001').collection('tokens').doc('token_001').update({
        token_status: 'delivered'
      })
    );
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 6. QUEUES collection
// ════════════════════════════════════════════════════════════════════════════
describe('queues collection', () => {
  test('[ALLOW] customer can read queue', async () => {
    await assertSucceeds(customerDb().collection('queues').doc('Idly').get());
  });
  test('[ALLOW] customer can list queues', async () => {
    await assertSucceeds(customerDb().collection('queues').get());
  });

  // Writes — ALL DENIED (ADR-001)
  test('[DENY] customer cannot create queue entry directly', async () => {
    await assertFails(customerDb().collection('queues').doc('NewItem').set({
      item_name: 'NewItem', queue: [], total_prep_units_ahead: 0
    }));
  });
  test('[DENY] customer cannot update queue directly', async () => {
    await assertFails(customerDb().collection('queues').doc('Idly').update({
      total_prep_units_ahead: 99
    }));
  });
  test('[DENY] staff cannot update queue via client SDK', async () => {
    await assertFails(staffDb().collection('queues').doc('Idly').update({ total_prep_units_ahead: 0 }));
  });
  test('[DENY] admin cannot write queue via client SDK', async () => {
    await assertFails(adminDb().collection('queues').doc('Idly').update({ queue: [] }));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 7. WALLETS collection
// ════════════════════════════════════════════════════════════════════════════
describe('wallets collection', () => {
  test('[ALLOW] customer can read own wallet', async () => {
    await assertSucceeds(customerDb().collection('wallets').doc(CUSTOMER_UID).get());
  });
  test('[DENY] customer cannot read another wallet', async () => {
    await assertFails(customerDb().collection('wallets').doc(OTHER_UID).get());
  });
  test('[ALLOW] admin can read any wallet', async () => {
    await assertSucceeds(adminDb().collection('wallets').doc(CUSTOMER_UID).get());
  });

  // Writes — ALL DENIED (ADR-001: wallet debit/credit via backend only)
  test('[DENY] customer cannot initialize own wallet directly', async () => {
    await assertFails(customerDb().collection('wallets').doc(CUSTOMER_UID).set({
      balance: 0, total_added: 0, total_spent: 0
    }));
  });
  test('[DENY] customer cannot debit own wallet directly', async () => {
    await assertFails(customerDb().collection('wallets').doc(CUSTOMER_UID).update({
      balance: 420, total_spent: 80
    }));
  });
  test('[DENY] staff cannot update wallets via client SDK', async () => {
    await assertFails(staffDb().collection('wallets').doc(CUSTOMER_UID).update({ balance: 0 }));
  });
  test('[DENY] admin cannot credit wallet via client SDK', async () => {
    await assertFails(adminDb().collection('wallets').doc(CUSTOMER_UID).update({ balance: 9999 }));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 8. WALLET_TRANSACTIONS collection
// ════════════════════════════════════════════════════════════════════════════
describe('wallet_transactions collection', () => {
  test('[ALLOW] customer can read own transactions', async () => {
    await assertSucceeds(customerDb().collection('wallet_transactions').doc('tx_001').get());
  });
  test('[DENY] customer cannot read other user transactions', async () => {
    await assertFails(customerDb().collection('wallet_transactions').doc('tx_002').get());
  });
  test('[ALLOW] admin can read any transaction', async () => {
    await assertSucceeds(adminDb().collection('wallet_transactions').doc('tx_001').get());
  });

  // Writes — ALL DENIED (ADR-001)
  test('[DENY] customer cannot create purchase transactions directly', async () => {
    await assertFails(customerDb().collection('wallet_transactions').add({
      user_uid: CUSTOMER_UID, amount: 80, type: 'purchase', status: 'success'
    }));
  });
  test('[DENY] customer cannot update own transactions', async () => {
    await assertFails(customerDb().collection('wallet_transactions').doc('tx_001').update({
      order_id: 'order_001'
    }));
  });
  test('[DENY] admin cannot write transactions via client SDK', async () => {
    await assertFails(adminDb().collection('wallet_transactions').add({
      user_uid: CUSTOMER_UID, amount: 500, type: 'deposit'
    }));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 9. PENDING_DEPOSITS collection
// ════════════════════════════════════════════════════════════════════════════
describe('pending_deposits collection', () => {
  test('[ALLOW] customer can read own deposit', async () => {
    await assertSucceeds(customerDb().collection('pending_deposits').doc('dep_001').get());
  });
  test('[DENY] customer cannot read another deposit', async () => {
    await assertFails(customerDb().collection('pending_deposits').doc('dep_002').get());
  });
  test('[ALLOW] admin can read any deposit', async () => {
    await assertSucceeds(adminDb().collection('pending_deposits').doc('dep_001').get());
  });

  // Writes — ALL DENIED (ADR-001: deposit creation via Razorpay webhook → FastAPI)
  test('[DENY] customer cannot create pending deposit directly', async () => {
    await assertFails(customerDb().collection('pending_deposits').add({
      user_uid: CUSTOMER_UID, amount: 200, status: 'awaiting_review'
    }));
  });
  test('[DENY] admin cannot approve deposit via client SDK', async () => {
    await assertFails(adminDb().collection('pending_deposits').doc('dep_001').update({
      status: 'approved'
    }));
  });
  test('[DENY] staff cannot update deposits via client SDK', async () => {
    await assertFails(staffDb().collection('pending_deposits').doc('dep_001').update({
      status: 'approved'
    }));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 10. REFUND_REQUESTS collection
// ════════════════════════════════════════════════════════════════════════════
describe('refund_requests collection', () => {
  test('[ALLOW] customer can read own refund request', async () => {
    await assertSucceeds(customerDb().collection('refund_requests').doc('ref_001').get());
  });
  test('[DENY] customer cannot read another user\'s refund request', async () => {
    await assertFails(customerDb().collection('refund_requests').doc('ref_002').get());
  });
  test('[ALLOW] admin can read any refund request', async () => {
    await assertSucceeds(adminDb().collection('refund_requests').doc('ref_001').get());
  });

  // Writes — ALL DENIED (ADR-001: all refund ops via FastAPI)
  test('[DENY] customer cannot create refund request directly', async () => {
    await assertFails(customerDb().collection('refund_requests').add({
      user_uid: CUSTOMER_UID, order_id: 'order_001', status: 'refund_requested'
    }));
  });
  test('[DENY] customer cannot update refund status directly', async () => {
    await assertFails(customerDb().collection('refund_requests').doc('ref_001').update({
      status: 'approved'
    }));
  });
  test('[DENY] admin cannot approve refund via client SDK', async () => {
    await assertFails(adminDb().collection('refund_requests').doc('ref_001').update({
      status: 'approved'
    }));
  });
  test('[DENY] staff cannot update refund status via client SDK', async () => {
    await assertFails(staffDb().collection('refund_requests').doc('ref_001').update({
      status: 'refund_under_review'
    }));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 11. RECOMMENDATIONS collection
// ════════════════════════════════════════════════════════════════════════════
describe('Recommendations collection', () => {
  test('[ALLOW] customer can read recommendations', async () => {
    await assertSucceeds(customerDb().collection('Recommendations').doc('CanteenBuzz').get());
  });
  test('[DENY] unauthenticated user cannot read recommendations', async () => {
    await assertFails(anonDb().collection('Recommendations').doc('CanteenBuzz').get());
  });
  
  // Writes — ALL DENIED (Backend Cloud Functions only)
  test('[DENY] customer cannot write recommendations', async () => {
    await assertFails(customerDb().collection('Recommendations').doc('CanteenBuzz').set({
      topItems: []
    }));
  });
  test('[DENY] staff cannot write recommendations via client SDK', async () => {
    await assertFails(staffDb().collection('Recommendations').doc('CanteenBuzz').set({
      topItems: []
    }));
  });
  test('[DENY] admin cannot write recommendations via client SDK', async () => {
    await assertFails(adminDb().collection('Recommendations').doc('CanteenBuzz').set({
      topItems: []
    }));
  });
});

// ════════════════════════════════════════════════════════════════════════════
// 12. CATCH-ALL — unlisted collections denied
// ════════════════════════════════════════════════════════════════════════════
describe('Catch-all: unlisted collections denied', () => {
  test('[DENY] cannot read from unknown collection', async () => {
    await assertFails(customerDb().collection('unknown_collection').doc('doc1').get());
  });
  test('[DENY] cannot write to unknown collection', async () => {
    await assertFails(customerDb().collection('unknown_collection').add({ data: 'anything' }));
  });
  test('[DENY] admin cannot write to unknown collection via client SDK', async () => {
    await assertFails(adminDb().collection('audit_logs').add({ event: 'test' }));
  });
});
