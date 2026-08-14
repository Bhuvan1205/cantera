import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_colors.dart';
import '../models/group_order_model.dart';
import '../services/group_order_service.dart';

class GroupOrderDetailsScreen extends StatefulWidget {
  const GroupOrderDetailsScreen({super.key, required this.groupId, this.onLeave});
  final String groupId;
  final VoidCallback? onLeave;

  @override
  State<GroupOrderDetailsScreen> createState() => _GroupOrderDetailsScreenState();
}

class _GroupOrderDetailsScreenState extends State<GroupOrderDetailsScreen> {
  StreamSubscription<GroupOrder?>? _groupSub;
  GroupOrder? _group;
  bool _isLoading = true;
  String? _errorMsg;
  int _retryCount = 0;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _groupSub?.cancel();
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    _groupSub = GroupOrderService.instance.watch(widget.groupId).listen(
      (group) {
        if (!mounted) return;
        setState(() {
          _group = group;
          _isLoading = false;
          _retryCount = 0;
        });
      },
      onError: (e) {
        if (!mounted) return;
        debugPrint('GroupOrderDetailsScreen stream error: $e');
        if (_retryCount < 3) {
          _retryCount++;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _startListening();
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMsg = 'Unable to load group order.';
          });
        }
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMsg != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Order')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(_errorMsg!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _retryCount = 0;
                  _startListening();
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLeaving
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Leave group order?'),
                            content: const Text(
                              'The group order could not be loaded. Do you want to leave it so you can start or join a new one?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                child: const Text('Leave'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !mounted) return;
                        setState(() => _isLeaving = true);
                        try {
                          await GroupOrderService.instance.leave(widget.groupId);
                        } catch (_) {
                          // If leave fails (e.g. already cancelled/completed), proceed anyway.
                        }
                        if (!mounted) return;
                        widget.onLeave?.call();
                        Navigator.pop(context);
                      },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: _isLeaving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Leave Group'),
              ),
            ],
          ),
        ),
      );
    }

    final group = _group;
    if (group == null) {
      return const Scaffold(body: Center(child: Text('Group order not found.')));
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isInitiator = uid == group.initiatorUid;
    final groupId = widget.groupId;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Order')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: QrImageView(
              data: 'cantera://group/join?code=${group.groupCode}',
              size: 180,
            ),
          ),
          Center(
            child: Text(
              group.groupCode,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 20),
          Text('${group.members.length} members', style: const TextStyle(fontWeight: FontWeight.w800)),
          ...group.members.map((m) => ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('${m['name'] ?? 'Member'}'),
              )),
          const Divider(),
          ...group.items.map((i) {
            final owner = group.members.cast<Map<String, dynamic>>().firstWhere(
                  (m) => m['uid'] == i.addedByUid,
                  orElse: () => {'name': 'member'},
                );
            return ListTile(
              title: Text('${i.menuItemId} × ${i.quantity}'),
              subtitle: Text('Added by ${owner['name'] ?? 'member'}'),
            );
          }),
          const SizedBox(height: 20),
          if (isInitiator && group.status == 'OPEN')
            ElevatedButton(
              onPressed: () async {
                try {
                  await GroupOrderService.instance.checkout(groupId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Pay Group Total'),
            )
          else
            Text(
              group.status == 'PAYING' ? 'Payment in progress' : 'Waiting for initiator to pay',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          if (group.status == 'OPEN')
            TextButton(
              onPressed: _isLeaving
                  ? null
                  : () async {
                      final okay = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(isInitiator ? 'Cancel group order?' : 'Leave group order?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
                          ],
                        ),
                      );
                      if (okay == true) {
                        setState(() => _isLeaving = true);
                        try {
                          if (isInitiator) {
                            await GroupOrderService.instance.cancel(groupId);
                          } else {
                            await GroupOrderService.instance.leave(groupId);
                          }
                          if (!mounted) return;
                          widget.onLeave?.call();
                          Navigator.pop(context);
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => _isLeaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: _isLeaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isInitiator ? 'Cancel group order' : 'Leave group order'),
            ),
        ],
      ),
    );
  }
}
