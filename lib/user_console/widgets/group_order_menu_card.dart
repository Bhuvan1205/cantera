import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../models/group_order_model.dart';
import '../utils/app_keys.dart';

class GroupOrderMenuCard extends StatelessWidget {
  const GroupOrderMenuCard({super.key, this.group, required this.onTap}); final GroupOrder? group; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Card(key: AppKeys.groupOrderCard, color: AppColors.summaryCard, child: ListTile(
    onTap: onTap, leading: const Icon(Icons.group_rounded, color: AppColors.primary),
    title: Text(group == null ? 'Start or Join Group Order' : 'Group ${group!.groupCode}', style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(group == null ? 'Order together and pay once' : '${group!.members.length} members · ${group!.items.length} items'), trailing: const Icon(Icons.chevron_right_rounded)));
}
