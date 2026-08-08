import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_colors.dart';
import '../models/group_order_model.dart';
import '../services/group_order_service.dart';

class GroupOrderDetailsScreen extends StatelessWidget {
  const GroupOrderDetailsScreen({super.key, required this.groupId}); final String groupId;
  @override Widget build(BuildContext context) => StreamBuilder<GroupOrder?>(stream: GroupOrderService.instance.watch(groupId), builder: (context, snap) {
    final group = snap.data; if (group == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final uid = FirebaseAuth.instance.currentUser?.uid; final isInitiator = uid == group.initiatorUid;
    return Scaffold(appBar: AppBar(title: const Text('Group Order')), body: ListView(padding: const EdgeInsets.all(24), children: [
      Center(child: QrImageView(data: 'cantera://group/join?code=${group.groupCode}', size: 180)), Center(child: Text(group.groupCode, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
      const SizedBox(height: 20), Text('${group.members.length} members', style: const TextStyle(fontWeight: FontWeight.w800)),
      ...group.members.map((m) => ListTile(leading: const Icon(Icons.person_outline), title: Text('${m['name'] ?? 'Member'}'))),
      const Divider(), ...group.items.map((i) {
        final owner = group.members.cast<Map<String, dynamic>>().firstWhere((m) => m['uid'] == i.addedByUid, orElse: () => {'name': 'member'});
        return ListTile(title: Text('${i.menuItemId} × ${i.quantity}'), subtitle: Text('Added by ${owner['name'] ?? 'member'}'));
      }),
      const SizedBox(height: 20), if (isInitiator && group.status == 'OPEN') ElevatedButton(onPressed: () async { try { await GroupOrderService.instance.checkout(groupId); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }, child: const Text('Pay Group Total')) else Text(group.status == 'PAYING' ? 'Payment in progress' : 'Waiting for initiator to pay', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
      if (group.status == 'OPEN') TextButton(onPressed: () async { final okay = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(isInitiator ? 'Cancel group order?' : 'Leave group order?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm'))])); if (okay == true) { if (isInitiator) { await GroupOrderService.instance.cancel(groupId); } else { await GroupOrderService.instance.leave(groupId); } } }, child: Text(isInitiator ? 'Cancel group order' : 'Leave group order')),
    ]));
  });
}
