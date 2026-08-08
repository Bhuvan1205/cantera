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
  Future<Map<String, dynamic>> checkout(String id) async => Map<String, dynamic>.from(await ApiClient.instance.post('/api/orders/group/checkout', body: {'group_id': id}, headers: {'Idempotency-Key': 'group-$id-${DateTime.now().microsecondsSinceEpoch}'}));
  Future<GroupOrder> _group(String path, Map<String, dynamic> body) async => GroupOrder.fromJson(Map<String, dynamic>.from(await ApiClient.instance.post('/api/orders/group$path', body: body)));
  Stream<GroupOrder?> watch(String groupId) => FirebaseFirestore.instance.collection('group_orders').doc(groupId).snapshots().map((doc) => doc.exists ? GroupOrder.fromFirestore(doc) : null);
}
