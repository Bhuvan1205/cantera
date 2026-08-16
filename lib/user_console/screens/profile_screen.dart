import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../wallet/models/wallet_model.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../wallet/services/wallet_service.dart';
import '../../wallet/utils/wallet_formatters.dart';
import '../services/auth_service.dart';
import '../utils/app_keys.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.isAdmin,
    this.onOpenScanner,
  });

  final bool isAdmin;
  final VoidCallback? onOpenScanner;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _currentPin;
  DateTime? _lastPinChange;
  bool _pinLoading = true;
  bool _pinVisible = false;

  @override
  void initState() {
    super.initState();
    _loadPinInfo();
  }

  Future<void> _loadPinInfo() async {
    final info = await AuthService.getPickupPinInfo();
    if (mounted) {
      setState(() {
        _currentPin = info.pin;
        _lastPinChange = info.lastChanged;
        _pinLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void _openWallet() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WalletScreen()),
    );
  }

  /// Shows the two-step Change PIN dialog (password → new PIN).
  Future<void> _showChangePinDialog() async {
    final passwordController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    bool isVerifying = false;
    bool passwordObscure = true;
    String? errorText;

    // Step 1: Password confirmation
    final passwordOk = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Confirm Your Password',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.primary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To change your Delivery PIN, please verify your account password first.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: passwordObscure,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.primary),
                decoration: InputDecoration(
                  labelText: 'Account Password',
                  errorText: errorText,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      passwordObscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () =>
                        setDS(() => passwordObscure = !passwordObscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final pw = passwordController.text.trim();
                      if (pw.isEmpty) {
                        setDS(() => errorText = 'Password cannot be empty');
                        return;
                      }
                      setDS(() {
                        isVerifying = true;
                        errorText = null;
                      });
                      try {
                        // Lightweight check — actual auth happens in changePickupPin
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) throw Exception('Not signed in.');
                        final cred = EmailAuthProvider.credential(
                          email: user.email!,
                          password: pw,
                        );
                        await user.reauthenticateWithCredential(cred);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop(true);
                      } catch (e) {
                        final msg = e.toString().replaceFirst('Exception: ', '');
                        setDS(() {
                          isVerifying = false;
                          errorText = msg.contains('wrong-password') ||
                                  msg.contains('invalid-credential')
                              ? 'Incorrect password. Please try again.'
                              : msg;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: isVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Continue',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (passwordOk != true || !mounted) return;

    // Step 2: Enter new PIN
    bool isSaving = false;
    String? pinError;

    final newPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Set New Delivery PIN',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.primary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a new 4-digit PIN. This PIN will be shown to the counter staff when collecting your Mess order.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  labelText: 'New 4-digit PIN',
                  errorText: pinError,
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmPinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 30-day warning banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You can only change your PIN once every 30 days.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final p1 = newPinController.text.trim();
                      final p2 = confirmPinController.text.trim();
                      if (p1.length != 4) {
                        setDS(() => pinError = 'PIN must be exactly 4 digits');
                        return;
                      }
                      if (p1 != p2) {
                        setDS(() => pinError = 'PINs do not match');
                        return;
                      }
                      setDS(() {
                        isSaving = true;
                        pinError = null;
                      });
                      try {
                        await AuthService.changePickupPin(
                          password: passwordController.text.trim(),
                          newPin: p1,
                        );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop(p1);
                      } catch (e) {
                        setDS(() {
                          isSaving = false;
                          pinError = e
                              .toString()
                              .replaceFirst('Exception: ', '');
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save PIN',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (newPin != null && mounted) {
      setState(() {
        _currentPin = newPin;
        _lastPinChange = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery PIN updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();

    // Generate up to 2-letter initials from display name
    final initials = displayName.isNotEmpty
        ? displayName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context, initials, displayName, email),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _InfoCard(
                    key: AppKeys.profileNameCard,
                    icon: Icons.person_outline_rounded,
                    label: 'Name',
                    value: displayName.isNotEmpty ? displayName : 'User',
                  ),
                  const SizedBox(height: 14),
                  _InfoCard(
                    key: AppKeys.profileEmailCard,
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: email.isNotEmpty ? email : 'No email available',
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 14),
                    _InfoCard(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Role',
                      value: 'Canteen Staff / Admin',
                      badge: 'STAFF',
                    ),
                  ],
                  const SizedBox(height: 14),
                  // ── Delivery PIN Card ──────────────────────────────────────
                  _PinCard(
                    currentPin: _currentPin,
                    lastPinChange: _lastPinChange,
                    isLoading: _pinLoading,
                    pinVisible: _pinVisible,
                    onToggleVisibility: () =>
                        setState(() => _pinVisible = !_pinVisible),
                    onChangeTap: _showChangePinDialog,
                  ),
                  const SizedBox(height: 14),
                  // ── Wallet Card ────────────────────────────────────────────
                  _WalletEntryCard(
                    key: AppKeys.profileWalletCard,
                    userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    onTap: _openWallet,
                  ),
                  const SizedBox(height: 32),
                  if (widget.isAdmin) ...[
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        key: AppKeys.profileScannerButton,
                        onPressed: widget.onOpenScanner,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Open QR Scanner'),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      key: AppKeys.profileSignOutButton,
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out'),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String initials,
    String displayName,
    String email,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back button ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Avatar + name ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty ? displayName : 'User',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 28),
          const Text(
            'Account Details',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// A tappable wallet entry card shown on the Profile screen.
/// Streams the live wallet balance for display.
class _WalletEntryCard extends StatelessWidget {
  const _WalletEntryCard({
    super.key,
    required this.userId,
    required this.onTap,
  });

  final String userId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WalletModel?>(
      stream: WalletService.watchWallet(userId),
      builder: (context, snap) {
        final wallet = snap.data;
        final isLoading =
            snap.connectionState == ConnectionState.waiting;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F382B), Color(0xFF1A5C42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cantora Wallet',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xAAFFFFFF),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      isLoading
                          ? Container(
                              width: 80,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            )
                          : Text(
                              wallet == null
                                  ? 'Set up wallet'
                                  : WalletFormatters.currency(wallet.balance),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white54,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// A single row in the profile info list (name, email, role, etc.).
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Optional pill badge shown on the trailing edge (e.g. 'STAFF').
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Delivery PIN card — shows current PIN and allows changing it.
class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.currentPin,
    required this.lastPinChange,
    required this.isLoading,
    required this.pinVisible,
    required this.onToggleVisibility,
    required this.onChangeTap,
  });

  final String? currentPin;
  final DateTime? lastPinChange;
  final bool isLoading;
  final bool pinVisible;
  final VoidCallback onToggleVisibility;
  final VoidCallback onChangeTap;

  String _nextChangeDate() {
    if (lastPinChange == null) return '';
    final next = lastPinChange!.add(const Duration(days: 30));
    final diff = next.difference(DateTime.now()).inDays;
    if (diff <= 0) return '';
    return 'Next change allowed in $diff day${diff == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final nextChangeInfo = _nextChangeDate();
    final canChange = nextChangeInfo.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.pin_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery PIN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 60,
                            child: LinearProgressIndicator(
                              backgroundColor: AppColors.border,
                              color: AppColors.primary,
                            ),
                          )
                        : Text(
                            (currentPin == null || currentPin!.isEmpty)
                                ? 'Not set'
                                : (pinVisible ? currentPin! : '• • • •'),
                            style: TextStyle(
                              fontSize: (currentPin != null && currentPin!.isNotEmpty) && pinVisible ? 22 : 18,
                              fontWeight: FontWeight.w800,
                              color: (currentPin == null || currentPin!.isEmpty)
                                  ? AppColors.textMuted
                                  : AppColors.primary,
                              letterSpacing:
                                  (currentPin != null && currentPin!.isNotEmpty) && pinVisible ? 6 : 4,
                            ),
                          ),
                  ],
                ),
              ),
              // Eye toggle
              if (currentPin != null && currentPin!.isNotEmpty)
                IconButton(
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    pinVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          // Bottom row: cooldown info + change button
          Row(
            children: [
              Expanded(
                child: nextChangeInfo.isNotEmpty
                    ? Row(
                        children: [
                          const Icon(Icons.lock_clock_rounded,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              nextChangeInfo,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Your 4-digit Mess pickup PIN',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              GestureDetector(
                onTap: canChange ? onChangeTap : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: canChange
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    canChange ? 'Change PIN' : 'Locked',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: canChange ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
