// ignore_for_file: avoid_catches_without_on_clauses, avoid_print

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central service for all order-related Firestore writes.
///
/// Handles:
///  - Order creation (parent doc + per-counter token sub-documents)
///  - QR scan routing (bakery/beverages/continental → instant deliver;
///    mess → set preparing, require OTP)
///  - OTP verification for mess tokens
///  - Queue management (add on place, remove + advance on OTP verify)
class OrderService {
  static final _db = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────────────────────────────────
  // Place Order
  // ──────────────────────────────────────────────────────────────────────────

  /// Creates a parent `Orders` document and one `tokens` sub-document per
  /// counter.  Also decrements stock for quantifiable items and updates the
  /// `queues` collection for mess items.
  ///
  /// Returns the new order document ID.
  static Future<String> placeOrder({
    required Map<String, Map<String, dynamic>> cart,
    required String userId,
    String? preGeneratedOrderId,
    String? paymentMethod,
  }) async {
    if (cart.isEmpty) throw Exception('Cart is empty');

    final int baseToken = DateTime.now().millisecondsSinceEpoch % 100000;

    // ── Flat item list (kept for backward-compat with history / detail screens)
    final List<Map<String, dynamic>> orderItems = cart.entries
        .map((e) => {
              'name': e.value['name'],
              'price': e.value['price'],
              'quantity': e.value['quantity'],
              'category':
                  (e.value['category'] as String? ?? 'general').toLowerCase(),
            })
        .toList();

    final int subtotal = cart.entries.fold(
      0,
      (acc, e) =>
          acc + (e.value['price'] as int) * (e.value['quantity'] as int),
    );

    // ── Group cart entries by counter (category) ───────────────────────────
    // tokenItems  → used for the new subcollection schema
    // displayItems→ used in categoryTokens for the existing QR screen
    final Map<String, List<Map<String, dynamic>>> tokenItems = {};
    final Map<String, List<Map<String, dynamic>>> displayItems = {};

    for (final entry in cart.entries) {
      final cat =
          ((entry.value['category'] as String?) ?? 'general').toLowerCase();
      final qty = entry.value['quantity'] as int;
      final itemName = entry.value['name'] as String;
      final price = entry.value['price'] as int;

      tokenItems.putIfAbsent(cat, () => []).add({
        'item_name': itemName,
        'quantity': qty,
        'unit_price': price,
        'prep_units': cat == 'mess' ? _calcPrepUnits(qty) : 0.0,
      });

      displayItems.putIfAbsent(cat, () => []).add({
        'name': itemName,
        'quantity': qty,
        'price': price,
      });
    }

    final sortedCategories = tokenItems.keys.toList()..sort();

    final orderRef = preGeneratedOrderId != null
        ? _db.collection('Orders').doc(preGeneratedOrderId)
        : _db.collection('Orders').doc();
    final orderId = orderRef.id;

    // ── Pre-calculate token data and IDs ──────────────────────────────────
    final Map<String, dynamic> finalCategoryTokens = {};
    final Map<String, Map<String, dynamic>> tokenDataMap = {};

    for (int i = 0; i < sortedCategories.length; i++) {
      final cat = sortedCategories[i];
      final catToken = (baseToken + i) % 100000;
      final items = tokenItems[cat]!;
      final isMess = cat == 'mess';

      final tokenRef = orderRef.collection('tokens').doc();
      final tokenId = tokenRef.id;
      final qrCodeData = '$orderId::$tokenId';

      finalCategoryTokens[cat] = {
        'tokenId': qrCodeData,
        'tokenNumber': catToken,
        'status': 'placed',
        'items': displayItems[cat],
      };

      // Mess-specific data
      String? otp;
      String? queueName;
      int? queuePosition;
      double? prepUnitsInQueue;

      if (isMess) {
        // Fetch static user pickup PIN
        final userDoc = await _db.collection('Users').doc(userId).get();
        String? userPin = userDoc.data()?['pickupPin'] as String?;
        if (userPin == null || userPin.isEmpty) {
          userPin = await _getOrCreateUserPin(userId);
        }
        otp = userPin;

        // Use the first mess item as the queue identifier
        queueName = items.first['item_name'] as String;

        // Sum weighted prep units across all items in this token
        prepUnitsInQueue = items.fold<double>(
          0.0,
          (acc, item) => acc + ((item['prep_units'] as num?)?.toDouble() ?? 0.0),
        );

        // Queue position = current queue length + 1
        final queueSnap =
            await _db.collection('queues').doc(queueName).get();
        final existingQueue =
            queueSnap.data()?['queue'] as List<dynamic>? ?? [];
        queuePosition = existingQueue.length + 1;
      }

      tokenDataMap[cat] = {
        'token_id': tokenId,
        'token_ref': tokenRef,
        'counter': cat,
        'items': items,
        'token_status': 'placed',
        'token_number': catToken,
        'qr_valid': true,
        'qr_code_data': qrCodeData,
        'otp': isMess ? otp : null,
        'otp_verified': isMess ? false : null,
        'queue_name': isMess ? queueName : null,
        'queue_position': isMess ? queuePosition : null,
        'prep_units_in_queue': isMess ? prepUnitsInQueue : null,
        'prep_start_time': null,
        'prep_end_time': null,
        'prep_duration_mins': null,
      };
    }

    // ── Step 1: Create parent order document with final categoryTokens ─────
    final currentUser = FirebaseAuth.instance.currentUser;
    final userName = (currentUser?.displayName != null && currentUser!.displayName!.trim().isNotEmpty)
        ? currentUser.displayName!.trim()
        : 'Customer';

    await orderRef.set({
      'userId': userId,
      'userName': userName,
      'items': orderItems,
      'total': subtotal,
      'status': 'placed',
      'overall_status': 'active',
      'tokenNumber': baseToken,
      'timestamp': FieldValue.serverTimestamp(),
      'categoryTokens': finalCategoryTokens,
      'order_id': orderId,
      'paymentMethod': paymentMethod,
    });

    // ── Step 2: Create one token sub-document per counter ─────────────────
    for (final cat in sortedCategories) {
      final tData = tokenDataMap[cat]!;
      final tokenRef = tData['token_ref'] as DocumentReference;
      final writeMap = Map<String, dynamic>.from(tData)..remove('token_ref');

      await tokenRef.set(writeMap);

      final isMess = cat == 'mess';
      final queueName = tData['queue_name'] as String?;
      final prepUnitsInQueue = tData['prep_units_in_queue'] as double?;
      final tokenId = tData['token_id'] as String;

      // ── Add mess token to its queue document ─────────────────────────────
      if (isMess && queueName != null && prepUnitsInQueue != null) {
        final queueRef = _db.collection('queues').doc(queueName);
        final tokenNumber = tData['token_number'] as int;

        await queueRef.set(
          {
            'item_name': queueName,
            'avg_prep_time_mins': _defaultPrepTime(queueName),
            'queue': FieldValue.arrayUnion([
              {
                'token_id': tokenId,
                'order_id': orderId,
                'prep_units': prepUnitsInQueue,
                'token_number': tokenNumber,
                'status': 'waiting',
              }
            ]),
            'total_prep_units_ahead':
                FieldValue.increment(prepUnitsInQueue),
          },
          SetOptions(merge: true),
        );
      }
    }

    // ── Step 3: Stock decrement for quantifiable items ─────────────────────
    for (final entry in cart.entries) {
      final cat = (entry.value['category'] as String? ?? '').toLowerCase();
      final itemName =
          (entry.value['name'] as String? ?? '').trim().toLowerCase();

      // Mess, continental items, tea, and coffee are non-quantifiable → skip
      if (cat == 'mess' || cat == 'continental' || itemName == 'tea' || itemName == 'coffee') continue;

      final docRef = _db.collection('Menu').doc(entry.key);
      final qty = entry.value['quantity'] as int;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final int current =
            ((snap.data()?['stock'] ?? 0) as num).toInt();
        tx.update(docRef, {'stock': current - qty});
      });
    }

    return orderId;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // QR Scan Handler
  // ──────────────────────────────────────────────────────────────────────────

  /// Entry point for all QR scan events (both admin and student-side scanners).
  ///
  /// Supported formats:
  ///  - New:    `"<orderId>::<tokenDocId>"`  — looks up token in subcollection
  ///  - Legacy: plain `"<orderId>"`          — marks whole order delivered
  ///  - Old:    `"<orderId>::<category>"`    — falls back to categoryTokens map
  static Future<String> handleQrScan(String scannedValue) async {
    final trimmed = scannedValue.trim();

    if (trimmed.contains('::')) {
      final parts = trimmed.split('::');
      if (parts.length == 2) {
        return await _handleTokenScan(parts[0], parts[1]);
      }
    }

    // Legacy plain orderId
    return await _handleLegacyOrderScan(trimmed);
  }

  /// Handles `"<orderId>::<secondPart>"` format.
  ///
  /// Tries to find `secondPart` as a token document ID in the subcollection.
  /// Falls back to treating it as a category name (old schema).
  static Future<String> _handleTokenScan(
    String orderId,
    String tokenOrCategory,
  ) async {
    final tokenRef = _db
        .collection('Orders')
        .doc(orderId)
        .collection('tokens')
        .doc(tokenOrCategory);

    final tokenSnap = await tokenRef.get();

    if (tokenSnap.exists) {
      // ── New schema ─────────────────────────────────────────────────────
      final data = tokenSnap.data()!;
      final counter = (data['counter'] as String? ?? '').toLowerCase();
      final tokenStatus =
          (data['token_status'] as String? ?? '').toLowerCase();

      final qrValid = data['qr_valid'] as bool? ?? false;

      // Fetch parent order document to check its category status
      final orderSnap = await _db.collection('Orders').doc(orderId).get();
      String parentCategoryStatus = 'placed';
      if (orderSnap.exists) {
        final categoryTokens = orderSnap.data()?['categoryTokens'] as Map<String, dynamic>?;
        if (categoryTokens != null && categoryTokens.containsKey(counter)) {
          parentCategoryStatus = (categoryTokens[counter]['status'] as String? ?? 'placed').toLowerCase();
        }
      }

      // Heal corrupt/inconsistent state:
      // We allow the scan to proceed if:
      // - qr_valid is true
      // - OR if the token status in either the sub-document or parent document is still 'placed'
      //   (meaning it hasn't successfully transitioned to preparing/delivered, or got stuck mid-way)
      final isDelivered = (tokenStatus == 'delivered' || parentCategoryStatus == 'delivered');
      
      if (!qrValid && tokenStatus != 'placed' && parentCategoryStatus != 'placed') {
        if (isDelivered) {
          throw Exception('This token has already been delivered');
        } else {
          throw Exception('This QR code has already been scanned');
        }
      }

      if (counter == 'mess') {
        // QR scan only confirms the student is at the mess counter.
        // Delivery requires PIN — do NOT set token_status to delivered here.
        if ((tokenStatus != 'preparing' && tokenStatus != 'delivered') || parentCategoryStatus == 'placed') {
          print('DEBUG: [Mess scan] Scanning tokenId $tokenOrCategory. Updating status to preparing...');

          // ── 1. Patch parent order categoryTokens status ──
          await _patchCategoryTokenStatus(orderId, counter, 'preparing');

          // ── 2. Promote parent order status to 'preparing' ──
          try {
            final parentSnap = await _db.collection('Orders').doc(orderId).get();
            final parentStatus =
                (parentSnap.data()?['status'] as String? ?? '').toLowerCase();
            if (parentStatus == 'placed') {
              await _db
                  .collection('Orders')
                  .doc(orderId)
                  .update({'status': 'preparing'});
              print('DEBUG: [Mess scan] Parent order $orderId status promoted to preparing');
            }
          } catch (e) {
            print('DEBUG: [Mess scan] Failed to update parent order status: $e');
          }

          // ── 3. Reflect the queue entry status ──
          final queueName = data['queue_name'] as String?;
          if (queueName != null) {
            final queueRef = _db.collection('queues').doc(queueName);
            final freshSnap = await queueRef.get();
            if (freshSnap.exists) {
              final queue = _mutableQueue(freshSnap);
              final idx = queue.indexWhere((e) => e['token_id'] == tokenOrCategory);
              if (idx >= 0) {
                queue[idx]['status'] = 'preparing';
                await queueRef.update({'queue': queue});
                print('DEBUG: [Mess scan] Queue $queueName entry status updated to preparing');
              } else {
                print('DEBUG: [Mess scan] Warning: TokenId $tokenOrCategory not found in queue $queueName!');
              }
            } else {
              print('DEBUG: [Mess scan] Warning: Queue $queueName does not exist!');
            }
          }

          // ── 4. Finally, update token sub-document and deactivate QR code atomically ──
          await tokenRef.update({
            'token_status': 'preparing',
            'prep_start_time': Timestamp.now(),
            'qr_valid': false,
          });
          print('DEBUG: [Mess scan] Token document updated to preparing and qr_valid set to false');
        } else {
          // If already preparing/delivered, but qr_valid was somehow true, ensure it gets deactivated
          await tokenRef.update({'qr_valid': false});
          print('DEBUG: [Mess scan] Token was already preparing/delivered. Invalidated qr_valid.');
        }
        return 'mess_preparing';
      } else {
        // Bakery, beverages, continental → instant delivery on QR scan
        if (tokenStatus == 'delivered' && parentCategoryStatus == 'delivered') {
          throw Exception('This token has already been delivered');
        }
        print('DEBUG: [Standard scan] Scanning counter $counter. Updating status to delivered...');

        // ── 1. Patch parent category status ──
        await _patchCategoryTokenStatus(orderId, counter, 'delivered');

        // ── 2. Update overall status ──
        await _updateOverallStatus(orderId);

        // ── 3. Finally, update token sub-document and deactivate QR code atomically ──
        await tokenRef.update({
          'token_status': 'delivered',
          'qr_valid': false,
        });
        print('DEBUG: [Standard scan] Token document updated to delivered and qr_valid set to false');
      }
      return 'delivered';
    }

    // ── Old schema (tokenOrCategory is a category name) ──────────────────
    return await _handleCategoryTokenScan(orderId, tokenOrCategory);
  }

  /// Old schema fallback: status is stored inside `categoryTokens` on the
  /// parent document (no `tokens` subcollection).
  static Future<String> _handleCategoryTokenScan(
    String orderId,
    String category,
  ) async {
    final orderDoc =
        await _db.collection('Orders').doc(orderId).get();
    if (!orderDoc.exists) throw Exception('Order not found');

    final data = orderDoc.data()!;
    final categoryTokens =
        data['categoryTokens'] as Map<String, dynamic>?;

    if (categoryTokens == null || !categoryTokens.containsKey(category)) {
      throw Exception('Invalid token — category not found in this order');
    }

    final catData = categoryTokens[category] as Map<String, dynamic>;
    final catStatus =
        (catData['status'] as String? ?? 'placed').toLowerCase();

    if (catStatus == 'delivered') {
      throw Exception(
        'This ${_categoryDisplayName(category)} token has already been used',
      );
    }

    await _db.collection('Orders').doc(orderId).update({
      'categoryTokens.$category.status': 'delivered',
    });

    // Promote whole order when all category tokens are done
    final updated =
        await _db.collection('Orders').doc(orderId).get();
    final updatedTokens =
        updated.data()?['categoryTokens'] as Map<String, dynamic>?;

    if (updatedTokens != null) {
      final allDone = updatedTokens.values.every((v) {
        final s =
            ((v as Map<String, dynamic>)['status'] as String? ?? '');
        return s.toLowerCase() == 'delivered';
      });
      if (allDone) {
        await _db.collection('Orders').doc(orderId).update({
          'status': 'delivered',
          'overall_status': 'completed',
        });
      }
    }
    return 'delivered';
  }

  /// Legacy: plain orderId — marks the entire order delivered.
  static Future<String> _handleLegacyOrderScan(String orderId) async {
    final orderDoc =
        await _db.collection('Orders').doc(orderId).get();
    if (!orderDoc.exists) throw Exception('Order not found');

    final data = orderDoc.data()!;
    final currentStatus =
        (data['status'] as String? ?? 'pending').toLowerCase();

    if (currentStatus == 'delivered') {
      throw Exception('This token has already been used');
    }

    await _db.collection('Orders').doc(orderId).update({
      'status': 'delivered',
      'overall_status': 'completed',
    });
    return 'delivered';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // OTP Verification (Mess counter only)
  // ──────────────────────────────────────────────────────────────────────────

  /// Verifies the 4-digit OTP for a known mess token.
  ///
  /// On success:
  ///  - Marks the token delivered, records prep timing
  ///  - Removes the entry from the `queues` document
  ///  - Advances the next queue entry (sets prep_start_time + 'preparing')
  ///  - Updates the parent order's overall_status if all tokens are done
  static Future<void> verifyMessOtp({
    required String orderId,
    required String tokenId,
    required String otp,
  }) async {
    final tokenRef = _db
        .collection('Orders')
        .doc(orderId)
        .collection('tokens')
        .doc(tokenId);

    final tokenSnap = await tokenRef.get();
    if (!tokenSnap.exists) throw Exception('Token not found');

    final data = tokenSnap.data()!;

    if ((data['counter'] as String? ?? '') != 'mess') {
      throw Exception('PIN verification is only applicable to Mess tokens');
    }
    if (data['otp_verified'] == true ||
        (data['token_status'] as String? ?? '') == 'delivered') {
      throw Exception('This order has already been delivered');
    }
    if (data['otp'] != otp) {
      throw Exception('Incorrect PIN — please try again');
    }

    final now = Timestamp.now();
    final prepStart = data['prep_start_time'] as Timestamp?;
    double? prepDurationMins;
    if (prepStart != null) {
      final diffSeconds = now.seconds - prepStart.seconds;
      prepDurationMins = diffSeconds / 60.0;
    }

    await tokenRef.update({
      'otp_verified': true,
      'token_status': 'delivered',
      'prep_end_time': now,
      'prep_duration_mins': prepDurationMins,
    });

    // Keep categoryTokens in sync so the QR screen shows the correct status
    await _patchCategoryTokenStatus(orderId, 'mess', 'delivered');

    // Remove from queue and advance next entries
    final queueName = data['queue_name'] as String?;
    if (queueName != null) {
      final prepUnits =
          (data['prep_units_in_queue'] as num?)?.toDouble() ?? 0.0;
      await _removeFromQueueAndAdvance(
        orderId: orderId,
        tokenId: tokenId,
        queueName: queueName,
        prepUnits: prepUnits,
      );
    }

    await _updateOverallStatus(orderId);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Queue Management (internal)
  // ──────────────────────────────────────────────────────────────────────────

  /// Removes [tokenId] from the named queue, recalculates
  /// `total_prep_units_ahead`, and advances tokens now at index 0 or 1 to
  /// `preparing`.
  static Future<void> _removeFromQueueAndAdvance({
    required String orderId,
    required String tokenId,
    required String queueName,
    required double prepUnits,
  }) async {
    print('DEBUG: [Queue remove] _removeFromQueueAndAdvance called for orderId: $orderId, tokenId: $tokenId, queueName: $queueName');
    final queueRef = _db.collection('queues').doc(queueName);
    final queueSnap = await queueRef.get();
    if (!queueSnap.exists) {
      print('DEBUG: [Queue remove] Warning: Queue document does not exist for $queueName');
      return;
    }
 
    final queue = _mutableQueue(queueSnap);
    print('DEBUG: [Queue remove] Current queue token IDs: ${queue.map((e) => e['token_id'])}');
 
    final idx = queue.indexWhere((e) => e['token_id'] == tokenId);
    if (idx < 0) {
      print('DEBUG: [Queue remove] Warning: tokenId $tokenId not found in queue list! Early returning.');
      return;
    }
 
    queue.removeAt(idx);
    print('DEBUG: [Queue remove] Removed entry at index $idx. New queue size: ${queue.length}');
 
    // Recalculate total waiting units
    final waitingUnits = queue
        .where((e) => (e['status'] as String? ?? '') == 'waiting')
        .fold<double>(
          0.0,
          (acc, e) => acc + ((e['prep_units'] as num?)?.toDouble() ?? 0.0),
        );
 
    await queueRef.update({
      'queue': queue,
      'total_prep_units_ahead': waitingUnits,
    });
    print('DEBUG: [Queue remove] Queue updated on Firestore with entry removed.');
 
    // Advance tokens now at index 0 or 1
    for (int i = 0; i < queue.length && i < 2; i++) {
      final entry = queue[i];
      if ((entry['status'] as String? ?? '') != 'waiting') continue;
 
      final nextTokenId = entry['token_id'] as String?;
      final nextOrderId = entry['order_id'] as String?;
      if (nextTokenId == null || nextOrderId == null) continue;
 
      print('DEBUG: [Queue remove] Advancing next-in-line token: nextTokenId: $nextTokenId, nextOrderId: $nextOrderId');
      final nextTokenRef = _db
          .collection('Orders')
          .doc(nextOrderId)
          .collection('tokens')
          .doc(nextTokenId);
 
      final nextSnap = await nextTokenRef.get();
      if (!nextSnap.exists) {
        print('DEBUG: [Queue remove] Warning: nextTokenRef does not exist!');
        continue;
      }
 
      final nextStatus =
          (nextSnap.data()?['token_status'] as String? ?? '').toLowerCase();
      if (nextStatus == 'preparing' || nextStatus == 'delivered') continue;
 
      await nextTokenRef.update({
        'token_status': 'preparing',
        'prep_start_time': Timestamp.now(),
      });
      print('DEBUG: [Queue remove] nextTokenRef status updated to preparing.');
 
      queue[i]['status'] = 'preparing';
    }
 
    // Persist updated queue statuses
    await queueRef.update({'queue': queue});
    print('DEBUG: [Queue remove] Queue list advanced statuses persisted successfully.');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Overall Status Helper
  // ──────────────────────────────────────────────────────────────────────────

  /// Promotes the parent order to `delivered / completed` when every token
  /// is delivered.  Checks the new subcollection first; falls back to the
  /// embedded `categoryTokens` map for old-schema orders.
  static Future<void> _updateOverallStatus(String orderId) async {
    final orderRef = _db.collection('Orders').doc(orderId);
    final tokensSnap = await orderRef.collection('tokens').get();

    if (tokensSnap.docs.isNotEmpty) {
      final allDone = tokensSnap.docs.every(
        (doc) =>
            (doc.data()['token_status'] as String? ?? '') == 'delivered',
      );
      if (allDone) {
        await orderRef.update({
          'status': 'delivered',
          'overall_status': 'completed',
        });
      }
    } else {
      // Old schema — check categoryTokens
      final orderSnap = await orderRef.get();
      final categoryTokens =
          orderSnap.data()?['categoryTokens'] as Map<String, dynamic>?;
      if (categoryTokens == null) return;

      final allDone = categoryTokens.values.every((v) {
        return ((v as Map<String, dynamic>)['status'] as String? ?? '') ==
            'delivered';
      });
      if (allDone) {
        await orderRef.update({
          'status': 'delivered',
          'overall_status': 'completed',
        });
      }
    }
  }

  /// Patches `categoryTokens.<counter>.status` on the parent doc so the
  /// existing `qr_screen.dart` shows the correct delivered state.
  static Future<void> _patchCategoryTokenStatus(
    String orderId,
    String counter,
    String status,
  ) async {
    try {
      await _db.collection('Orders').doc(orderId).update({
        'categoryTokens.$counter.status': status,
      });
    } catch (_) {
      // categoryTokens may be absent on very old orders — safe to ignore
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Utilities
  // ──────────────────────────────────────────────────────────────────────────

  /// Weighted prep units for mess items based on quantity ordered.
  static double _calcPrepUnits(int qty) {
    if (qty == 1) return 1.0;
    if (qty == 2) return 1.5;
    return 2.0; // qty 3+
  }

  /// Default average prep time (minutes) for each mess item.
  /// Used to initialise a queue document if it does not yet exist.
  static int _defaultPrepTime(String itemName) {
    const times = <String, int>{
      'Plain Dosa': 3,
      'Masala Dosa': 4,
      'Onion Dosa': 4,
      'Idly': 6,
      'Vada': 5,
      'Poori': 4,
      'Veg Noodles': 7,
      'Veg Manchurian': 8,
      'Paneer Fried Rice': 9,
      'Schezwan Noodles': 8,
      'Veg Fried Rice': 8,
      'Manchurian Noodles': 9,
      'Manchurian Fried Rice': 9,
      'Schezwan Fried Rice': 8,
      'Schezwan Manchurian': 9,
      'Jeera Rice': 4,
      'Veg Meals': 5,
      'Special Meals': 6,
      'Parota with Kurma': 5,
      'Curd Rice': 3,
      // Items without significant queue wait
      'Curd': 1,
      'Curry': 1,
      'Sweet': 1,
    };
    return times[itemName] ?? 5;
  }

  static String _categoryDisplayName(String cat) {
    switch (cat.toLowerCase()) {
      case 'bakery':
        return 'Bakery';
      case 'mess':
        return 'Mess';
      case 'beverages':
        return 'Beverages';
      case 'continental':
        return 'Continental';
      default:
        return cat;
    }
  }

  /// Returns a deep-mutable copy of the queue array from a Firestore snapshot.
  static List<Map<String, dynamic>> _mutableQueue(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    return List<Map<String, dynamic>>.from(
      (snap.data()?['queue'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  static Future<String> _getOrCreateUserPin(String userId) async {
    final userRef = _db.collection('Users').doc(userId);
    final pin = (1000 + Random().nextInt(9000)).toString();
    await userRef.set({'pickupPin': pin}, SetOptions(merge: true));
    return pin;
  }
}
