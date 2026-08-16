import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return const Color(0xFFD68A37); // Warm soft earthy amber/orange
    case 'placed':
      return const Color(0xFF5B7B7A); // Premium dusty teal/blue-grey
    case 'preparing':
      return const Color(0xFFB87333); // Copper/amber – kitchen in progress
    case 'delivered':
      return AppColors.success; // Eco success green
    case 'refund_pending':
      return const Color(0xFFB87333); // Warm amber
    case 'ready_for_pickup':
      return AppColors.success; // Green for ready
    case 'discarded':
      return AppColors.error; // Red for discarded
    case 'refunded':
    case 'cancelled':
      return AppColors.error; // Premium red/coral
    default:
      return AppColors.textMuted; // Soft warm slate grey
  }
}

