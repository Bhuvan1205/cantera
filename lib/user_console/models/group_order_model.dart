import 'package:cloud_firestore/cloud_firestore.dart';

class GroupOrderItem {
  const GroupOrderItem({required this.menuItemId, required this.quantity, required this.addedByUid});
  final String menuItemId; final int quantity; final String addedByUid;
  factory GroupOrderItem.fromJson(Map<String, dynamic> json) => GroupOrderItem(menuItemId: json['menuItemId'] as String, quantity: (json['quantity'] as num).toInt(), addedByUid: json['addedByUid'] as String);
}

class GroupOrder {
  const GroupOrder({required this.groupId, required this.groupCode, required this.initiatorUid, required this.status, required this.members, required this.memberUids, required this.items, this.orderId});
  final String groupId, groupCode, initiatorUid, status; final List<Map<String, dynamic>> members; final List<String> memberUids; final List<GroupOrderItem> items; final String? orderId;
  bool get isActive => status == 'OPEN' || status == 'PAYING';
  factory GroupOrder.fromJson(Map<String, dynamic> json) => GroupOrder(
    groupId: (json['group_id'] ?? json['groupId']) as String, groupCode: (json['group_code'] ?? json['groupCode']) as String,
    initiatorUid: (json['initiator_uid'] ?? json['initiatorUid']) as String, status: json['status'] as String,
    members: List<Map<String, dynamic>>.from(json['members'] ?? const []), memberUids: List<String>.from(json['member_uids'] ?? json['memberUids'] ?? const []),
    items: (json['items'] as List? ?? const []).map((x) => GroupOrderItem.fromJson(Map<String, dynamic>.from(x as Map))).toList(), orderId: json['order_id'] as String? ?? json['orderId'] as String?);
  factory GroupOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) => GroupOrder.fromJson({...?doc.data(), 'groupId': doc.id});
}
