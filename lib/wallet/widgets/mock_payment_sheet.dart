import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// A simulated payment bottom sheet used during testing.
///
/// This widget mimics the look and feel of a payment gateway checkout
/// without involving any real money or external SDK.
///
/// Usage: show via `MockPaymentSheet.show(context, amount: 200)`
/// and await the result:
///   - `true`  → simulated payment success
///   - `false` → simulated payment failure / cancellation
class MockPaymentSheet extends StatefulWidget {
  const MockPaymentSheet({super.key, required this.amount});

  final double amount;

  /// Shows the mock payment sheet as a modal bottom sheet.
  /// Returns `true` on simulated success, `false` on failure/cancel.
  static Future<bool> show(BuildContext context, {required double amount}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MockPaymentSheet(amount: amount),
    );
    return result ?? false;
  }

  @override
  State<MockPaymentSheet> createState() => _MockPaymentSheetState();
}

class _MockPaymentSheetState extends State<MockPaymentSheet> {
  bool _isProcessing = false;

  Future<void> _simulateSuccess() async {
    setState(() => _isProcessing = true);
    // Simulate network delay.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _simulateFailure() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        24,
        28,
        MediaQuery.viewInsetsOf(context).bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Gateway header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.payment_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mock Payment Gateway',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Testing mode — no real money involved',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Warning banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD966)),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_rounded, color: Color(0xFF856404), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This is a simulated payment. Replace with real Razorpay key before going live.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF856404),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Amount display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.summaryCard,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  'Amount to Add',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${widget.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Credits will be added to your wallet after admin review',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Action buttons
          if (_isProcessing)
            const SizedBox(
              width: double.infinity,
              height: 56,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 14),
                    Text(
                      'Processing payment…',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _simulateSuccess,
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text('Simulate Successful Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _simulateFailure,
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text('Simulate Failed Payment'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
