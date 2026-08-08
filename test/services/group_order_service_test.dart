import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/user_console/models/group_order_model.dart';

void main() {
  test('parses the backend group-order response', () {
    final group = GroupOrder.fromJson({
      'group_id': 'grp_1', 'group_code': 'ABC123', 'initiator_uid': 'u1',
      'status': 'OPEN', 'members': [{'uid': 'u1', 'name': 'Ada'}],
      'member_uids': ['u1'],
      'items': [{'menuItemId': 'tea', 'quantity': 2, 'addedByUid': 'u1'}],
    });
    expect(group.isActive, isTrue);
    expect(group.groupCode, 'ABC123');
    expect(group.items.single.quantity, 2);
  });
}
