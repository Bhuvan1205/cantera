import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../user_console/services/auth_service.dart';

/// The settings tab of the Canteen Staff Terminal.
///
/// Features switches for order and stock alerts, operational hour display,
/// active staff logs, and sign-out controls.
class StaffSettingsTab extends StatelessWidget {
  const StaffSettingsTab({
    super.key,
    required this.newOrderAlerts,
    required this.stockWarnings,
    required this.dailySummary,
    required this.onNewOrderAlertsChanged,
    required this.onStockWarningsChanged,
    required this.onDailySummaryChanged,
  });

  final bool newOrderAlerts;
  final bool stockWarnings;
  final bool dailySummary;
  final ValueChanged<bool> onNewOrderAlertsChanged;
  final ValueChanged<bool> onStockWarningsChanged;
  final ValueChanged<bool> onDailySummaryChanged;

  Future<void> _logout() async {
    await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).padding.bottom + 88),
      children: [
        // Header Section
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Configure your canteen's local workspace, active notification triggers, and active operational profiles.",
          style: TextStyle(
            height: 1.5,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 24),
        // 1. Operating Hours Card
        const _OperatingHoursCard(),
        const SizedBox(height: 16),
        // 2. Notifications Configuration Card
        _NotificationsCard(
          newOrderAlerts: newOrderAlerts,
          stockWarnings: stockWarnings,
          dailySummary: dailySummary,
          onNewOrderAlertsChanged: onNewOrderAlertsChanged,
          onStockWarningsChanged: onStockWarningsChanged,
          onDailySummaryChanged: onDailySummaryChanged,
        ),
        const SizedBox(height: 16),
        // 3. Team Roster Card
        const _TeamManagementCard(),
        const SizedBox(height: 16),
        // 4. Language & System Card
        const _GeneralSettingsCard(),
        const SizedBox(height: 24),
        // Logout Button
        TextButton.icon(
          onPressed: _logout,
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text(
            'Logout from Staff Terminal',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Footer Version
        const Text(
          'App Version 2.4.1 (Build 882) - Staff Workspace\nManaged by Terra Canteen Solutions',
          style: TextStyle(
            height: 1.5,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _OperatingHoursCard extends StatelessWidget {
  const _OperatingHoursCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operating Hours',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Global active hours for orders',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 6),
          const _ScheduleRow(
            label: 'Monday - Friday',
            value: '08:00 - 18:00',
          ),
          const _ScheduleRow(
            label: 'Saturday',
            value: '09:00 - 14:00',
          ),
          const _ScheduleRow(
            label: 'Sunday',
            value: 'Closed',
            valueColor: AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.newOrderAlerts,
    required this.stockWarnings,
    required this.dailySummary,
    required this.onNewOrderAlertsChanged,
    required this.onStockWarningsChanged,
    required this.onDailySummaryChanged,
  });

  final bool newOrderAlerts;
  final bool stockWarnings;
  final bool dailySummary;
  final ValueChanged<bool> onNewOrderAlertsChanged;
  final ValueChanged<bool> onStockWarningsChanged;
  final ValueChanged<bool> onDailySummaryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ToggleRow(
            title: 'New Order Alerts',
            subtitle: 'Instant push for every order',
            value: newOrderAlerts,
            onChanged: onNewOrderAlertsChanged,
          ),
          _ToggleRow(
            title: 'Stock Warnings',
            subtitle: 'Low inventory reminders',
            value: stockWarnings,
            onChanged: onStockWarningsChanged,
          ),
          _ToggleRow(
            title: 'Daily Summary',
            subtitle: 'Emailed at 8 PM',
            value: dailySummary,
            onChanged: onDailySummaryChanged,
            disabled: true,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: disabled ? AppColors.textMuted.withValues(alpha: 0.5) : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: disabled ? null : onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.16),
          ),
        ],
      ),
    );
  }
}

class _TeamManagementCard extends StatelessWidget {
  const _TeamManagementCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Team Management',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (index) {
              final labels = ['A', 'M', 'S'];
              return Transform.translate(
                offset: Offset(-index * 10, 0),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cardBg, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          const Text(
            'Staff members active today with operational roles.',
            style: TextStyle(
              height: 1.4,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Manage Permissions (Unavailable)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralSettingsCard extends StatelessWidget {
  const _GeneralSettingsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'SYSTEM CONFIGURATION',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          SizedBox(height: 8),
          _SettingItem(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'English (US)',
          ),
          _SettingItem(
            icon: Icons.currency_exchange_rounded,
            title: 'Currency & Region',
            subtitle: 'INR (₹) - India',
          ),
          _SettingItem(
            icon: Icons.shield_outlined,
            title: 'Security & Privacy',
            subtitle: 'Biometric lock enabled',
          ),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
