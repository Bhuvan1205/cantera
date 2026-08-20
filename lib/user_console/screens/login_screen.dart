import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../utils/app_keys.dart';
import '../widgets/labeled_input_field.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Login failed. Please try again.';
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Brand mark ─────────────────────────────────────────
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to your canteen account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Email ──────────────────────────────────────────────
                    LabeledInputField(
                      key: AppKeys.loginEmailField,
                      label: 'Email Address',
                      hint: 'you@example.com',
                      icon: Icons.mail_outline_rounded,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (value) {
                        final text = value?.trim().toLowerCase() ?? '';
                        if (text.isEmpty) return 'Enter your email';
                        if (!text.contains('@')) return 'Enter a valid email';
                        
                        // Testing admin bypass
                        if (text == 'vinjamuri.bhuvan@gmail.com') return null;
                        
                        final parts = text.split('@');
                        if (parts.length != 2 || parts[1] != 'mvsrec.edu.in') {
                          return 'Please use your official @mvsrec.edu.in email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Password ───────────────────────────────────────────
                    LabeledInputField(
                      key: AppKeys.loginPasswordField,
                      label: 'Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _login(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) return 'Enter your password';
                        return null;
                      },
                    ),

                    // ── Forgot Password ────────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => _ForgotPasswordDialog(
                              initialEmail: _emailController.text.trim(),
                            ),
                          );
                        },
                        child: const Text('Forgot Password?'),
                      ),
                    ),


                    // ── Error banner ───────────────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 32),

                    // ── Sign in button ─────────────────────────────────────
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        key: AppKeys.loginSubmitButton,
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const _ButtonSpinner()
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Register link ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton(
                          key: AppKeys.loginRegisterLink,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                          child: const Text('Register'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private shared widgets ──────────────────────────────────────────────────

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        // ── Email enumeration protection ──────────────────────────────────────
        // user-not-found must not reveal account existence; show generic success.
        case 'user-not-found':
          setState(() {
            _isSuccess = true;
          });
        // ── Local validation errors ───────────────────────────────────────────
        case 'invalid-email':
          setState(() {
            _errorMessage = 'Invalid email address format.';
          });
        // ── Rate-limiting ─────────────────────────────────────────────────────
        case 'too-many-requests':
          setState(() {
            _errorMessage =
                'Too many attempts. Please wait a moment before trying again.';
          });
        // ── Network / service / unknown Firebase errors ───────────────────────
        default:
          setState(() {
            _errorMessage = 'Something went wrong. Please try again.';
          });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg,
      title: const Text('Reset Password'),
      content: SizedBox(
        width: 400,
        child: _isSuccess
            ? const Text(
                'If an account exists for this email, a password reset link has been sent.',
                style: TextStyle(fontSize: 15),
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your email address and we will send you a link to reset your password.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    LabeledInputField(
                      label: 'Email Address',
                      hint: 'you@example.com',
                      icon: Icons.mail_outline_rounded,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      validator: (value) {
                        final text = value?.trim().toLowerCase() ?? '';
                        if (text.isEmpty) return 'Enter your email';
                        if (!text.contains('@')) return 'Enter a valid email';
                        
                        // Testing admin bypass
                        if (text == 'vinjamuri.bhuvan@gmail.com') return null;
                        
                        final parts = text.split('@');
                        if (parts.length != 2 || parts[1] != 'mvsrec.edu.in') {
                          return 'Please use your official @mvsrec.edu.in email address.';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        if (!_isSuccess)
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : (_isSuccess ? () => Navigator.of(context).pop() : _resetPassword),
          child: _isLoading
              ? const _ButtonSpinner()
              : Text(_isSuccess ? 'Close' : 'Send Reset Link'),
        ),
      ],
    );
  }
}

/// Inline error banner shown below form fields on auth failure.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorBorder, width: 1),
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
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small circular loading indicator for use inside buttons.
class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
    );
  }
}
