import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/api_client.dart';
import '../models/group_order_model.dart';

class GroupOrderService {
  GroupOrderService._();
  static final instance = GroupOrderService._();
  Future<GroupOrder> create({required List<Map<String, dynamic>> items}) async => GroupOrder.fromJson(Map<String, dynamic>.from(await ApiClient.instance.post('/api/orders/group/create', body: {'items': items})));
  Future<GroupOrder> join(String code, {List<Map<String, dynamic>> items = const []}) async => GroupOrder.fromJson(Map<String, dynamic>.from(await ApiClient.instance.post('/api/orders/group/join', body: {'group_code': code.toUpperCase(), 'items': items})));
  Future<GroupOrder> leave(String id) async => _group('/leave', {'group_id': id});
  Future<GroupOrder> cancel(String id) async => _group('/cancel', {'group_id': id});
  Future<GroupOrder> items(String id, String operation, String menuItemId, {int? quantity}) async => _group('/items', {'group_id': id, 'operation': operation, 'menu_item_id': menuItemId, if (quantity != null) 'quantity': quantity});
  Future<Map<String, dynamic>> checkout(String id, {String paymentMethod = 'wallet'}) async => Map<String, dynamic>.from(await ApiClient.instance.post('/api/orders/group/checkout', body: {'group_id': id, 'payment_method': paymentMethod}, headers: {'Idempotency-Key': 'group-$id-${DateTime.now().microsecondsSinceEpoch}'}));
  Future<void> forceExit() async => await ApiClient.instance.post('/api/orders/group/force_exit', body: {});
  Future<GroupOrder> _group(String path, Map<String, dynamic> body) async => GroupOrder.fromJson(Map<String, dynamic>.from(await ApiClient.instance.post('/api/orders/group$path', body: body)));
  Stream<GroupOrder?> watch(String groupId) => FirebaseFirestore.instance.collection('group_orders').doc(groupId).snapshots().map((doc) => doc.exists ? GroupOrder.fromFirestore(doc) : null);
  
  Future<GroupOrder?> getActiveGroup(String uid) async {
    debugPrint('[Hydration] Firestore query started for $uid');
    final snap = await FirebaseFirestore.instance.collection('group_orders').where('memberUids', arrayContains: uid).get(const GetOptions(source: Source.serverAndCache));
    debugPrint('[Hydration] Firestore query completed. Docs found: ${snap.docs.length}');
    for (final doc in snap.docs) {
      final group = GroupOrder.fromFirestore(doc);
      final rawData = doc.data();
      final expiresAt = rawData['expiresAt'] != null ? (rawData['expiresAt'] as Timestamp).toDate() : null;
      if (group.status == 'OPEN' && (expiresAt == null || expiresAt.isAfter(DateTime.now()))) return group;
      if (group.status == 'PAYING') return group;
    }
    return null;
  }
}


