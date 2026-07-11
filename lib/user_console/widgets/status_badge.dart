import 'package:flutter/material.dart';

/// A color-coded status badge used in order detail and order history screens.
///
/// **Variants:**
///   - Default: dot + text label (used in order detail headers)
///   - Compact (`compact: true`): text-only pill (used in list cards)
///
/// The [color] is sourced from [getStatusColor] in `order_status_utils.dart`.
///
/// **Usage:**
/// ```dart
/// StatusBadge(label: order.status, color: getStatusColor(order.status))
/// StatusBadge(label: order.status, color: statusColor, compact: true)
/// ```
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;

  /// When `true`, renders a compact text-only pill (for use inside list cards).
  /// When `false` (default), renders a pill with a colored dot indicator.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: compact ? _compactContent() : _fullContent(),
    );
  }

  /// Compact pill — text label only, small font. For list cards.
  Widget _compactContent() {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: color,
      ),
    );
  }

  /// Full pill — colored dot + text label. For screen headers.
  Widget _fullContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
