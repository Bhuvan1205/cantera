import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../theme/app_colors.dart';
import '../../config/app_config.dart';
import '../services/wallet_service.dart';
import '../utils/wallet_formatters.dart';
import '../widgets/mock_payment_sheet.dart';

/// Screen where the user enters an amount and initiates a wallet deposit.
///
/// Flow:
///  1. User enters amount (₹20–₹500, validated client-side).
///  2. User selects gateway (Razorpay / Mock for testing).
///  3. On "Add Money":
///     - Mock: shows [MockPaymentSheet], generates fake payment_id.
///     - Razorpay: opens the Razorpay checkout SDK.
///  4. On payment success → calls [WalletService.submitPendingDeposit].
///  5. Shows "pending review" confirmation and navigates back.
class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key, required this.userId});

  final String userId;

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  PaymentGateway _selectedGateway = PaymentGateway.mock;
  bool _isProcessing = false;
  String? _errorMessage;

  Razorpay? _razorpay;

  // Quick amount presets (all within ₹20–₹500 range).
  static const _presets = [50.0, 100.0, 200.0, 500.0];

  @override
  void initState() {
    super.initState();
    _initRazorpay();
  }

  void _initRazorpay() {
    if (kIsWeb) return; // Skip on web to prevent MissingPluginException
    _razorpay = Razorpay();
    _razorpay!.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handleRazorpaySuccess,
    );
    _razorpay!.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      _handleRazorpayError,
    );
    _razorpay!.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _razorpay?.clear();
    super.dispose();
  }

  // ── Amount validation ────────────────────────────────────────────────────────

  String? _validateAmount(String? value) =>
      WalletService.validateDepositAmount(value ?? '');

  double get _parsedAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  // ── Payment handlers ─────────────────────────────────────────────────────────

  String? _currentDepositId;

  Future<void> _initiatePayment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isProcessing) return;

    final amount = _parsedAmount;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final orderRes = await WalletService.createDepositOrder(amount);
      _currentDepositId = orderRes['deposit_id'] as String?;
      final rzpOrderId = orderRes['razorpay_order_id'] as String?;

      if (_selectedGateway == PaymentGateway.mock) {
        await _handleMockPayment(amount);
      } else {
        _handleRazorpayPayment(amount, rzpOrderId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleMockPayment(double amount) async {
    final success = await MockPaymentSheet.show(context, amount: amount);
    if (!mounted) return;

    if (!success) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Payment was cancelled or failed.';
      });
      return;
    }

    await _submitDeposit(amount);
  }

  void _handleRazorpayPayment(double amount, String? rzpOrderId) {
    final options = {
      'key': AppConfig.razorpayKeyId,
      'amount': (amount * 100).toInt(),
      'name': 'Cantora',
      'description': 'Wallet Top-up',
      'order_id': rzpOrderId,
      'prefill': <String, String>{},
      'theme': {'color': '#0F382B'},
    };

    try {
      _razorpay?.open(options);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Could not open payment gateway. Please try again.';
      });
    }
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    final amount = _parsedAmount;
    await _submitDeposit(amount);
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _errorMessage =
          'Payment failed: ${response.message ?? 'Please try again.'}';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _errorMessage = 'External wallet selected. Payment pending confirmation.';
    });
  }

  Future<void> _submitDeposit(double amount) async {
    final depId = _currentDepositId;
    if (depId == null) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Missing deposit record. Please try again.';
      });
      return;
    }

    try {
      // Send to backend for signature verification and wallet credit.
      await WalletService.verifyDeposit(depId);
      if (!mounted) return;
      _showSuccessAndPop(amount);
    } catch (e) {
      debugPrint('Deposit submission error: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to verify payment. Contact support with deposit ID: $depId';
      });
    }
  }

  void _showSuccessAndPop(double amount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Success! ${WalletFormatters.currency(amount)} has been added to your wallet.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    Navigator.maybePop(context);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Add Money'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            // ── Instructions ────────────────────────────────────────────────
            const Text(
              'How much would you like to add?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Credits are added after payment verification (₹20 – ₹500 per transaction).',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // ── Amount input ─────────────────────────────────────────────────
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
                decoration: const InputDecoration(
                  prefixText: '₹  ',
                  prefixStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.border,
                  ),
                ),
                validator: _validateAmount,
              ),
            ),
            const SizedBox(height: 20),

            // ── Quick-select chips ───────────────────────────────────────────
            Wrap(
              spacing: 10,
              children: _presets.map((amount) {
                final isSelected =
                    _amountController.text.trim() ==
                        amount.toInt().toString();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _amountController.text = amount.toInt().toString();
                    });
                    _formKey.currentState?.validate();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 0 : 1,
                      ),
                    ),
                    child: Text(
                      '₹${amount.toInt()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // ── Gateway selector ─────────────────────────────────────────────
            const Text(
              'PAYMENT GATEWAY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            _GatewayOption(
              label: 'Mock Gateway',
              subtitle: 'For testing — no real money',
              icon: Icons.science_rounded,
              color: const Color(0xFF856404),
              bgColor: const Color(0xFFFFF3CD),
              isSelected: _selectedGateway == PaymentGateway.mock,
              onTap: () => setState(() => _selectedGateway = PaymentGateway.mock),
            ),
            const SizedBox(height: 10),
            if (!kIsWeb) ...[
              _GatewayOption(
                label: 'Razorpay',
                subtitle: 'UPI · Card · Net Banking',
                icon: Icons.payment_rounded,
                color: AppColors.primary,
                bgColor: AppColors.primary.withValues(alpha: 0.08),
                isSelected: _selectedGateway == PaymentGateway.razorpay,
                onTap: () => setState(
                  () => _selectedGateway = PaymentGateway.razorpay,
                ),
              ),
              const SizedBox(height: 32),
            ],

            // ── Error banner ─────────────────────────────────────────────────
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.errorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── CTA ──────────────────────────────────────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _initiatePayment,
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _amountController.text.trim().isEmpty
                            ? 'Add Money'
                            : 'Add ₹${_amountController.text.trim()} to Wallet',
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Info note ────────────────────────────────────────────────────
            Center(
              child: Text(
                '1 Credit = ₹1 · Credits never expire',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GatewayOption extends StatelessWidget {
  const _GatewayOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
