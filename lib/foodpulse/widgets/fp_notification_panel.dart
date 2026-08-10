import 'package:flutter/material.dart';
import '../services/foodpulse_service.dart';

class FoodPulseNotificationPanel extends StatefulWidget {
  const FoodPulseNotificationPanel({super.key});

  @override
  State<FoodPulseNotificationPanel> createState() => _FoodPulseNotificationPanelState();
}

class _FoodPulseNotificationPanelState extends State<FoodPulseNotificationPanel> {
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifs = await FoodPulseService.getNotifications();
      if (mounted) {
        setState(() {
          notifications = notifs;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _markRead(String notifId) async {
    await FoodPulseService.markNotificationRead(notifId);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notifications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.notifications_none, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No notifications yet',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = notifications[index];
        final bool isRead = item['read'] ?? false;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isRead
                ? Colors.grey.withValues(alpha: 0.2)
                : Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Icon(
              Icons.psychology,
              color: isRead ? Colors.grey : Theme.of(context).primaryColor,
            ),
          ),
          title: Text(
            item['title'] ?? 'Notification',
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            item['body'] ?? '',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: !isRead
              ? IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  onPressed: () => _markRead(item['id']),
                )
              : null,
        );
      },
    );
  }
}
