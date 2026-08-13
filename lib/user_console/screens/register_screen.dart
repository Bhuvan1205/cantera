import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../theme/app_colors.dart';

import '../utils/app_keys.dart';
import '../widgets/labeled_input_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  /// True when Firebase Auth account was created but profile API call failed.
  /// In this state we show a retry option rather than a full re-registration.
  bool _profileSyncFailed = false;

  /// Registers a new user or retries profile synchronization after a previous failure.
  ///
  /// Firebase Auth and Firestore cannot participate in the same transaction.
  /// The approach here is:
  ///   1. Create Firebase Auth account (or detect an existing one on retry).
  ///   2. Call POST /api/users/profile (idempotent — safe to retry).
  ///   3. If step 2 fails, surface a recoverable error with a Retry button.
  ///
  /// Firestore Users/{uid} is the authoritative profile store.
  /// Firebase Auth displayName is NOT written here — it is not used as a
  /// source of truth for any app-level logic.
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _profileSyncFailed = false;
    });

    try {
      User? user;

      // ── Step 1: Firebase Auth account creation ──────────────────────────────
      // If the user already has an authenticated session (e.g. retry after
      // profile sync failure), skip createUser and use the existing account.
      final existingUser = FirebaseAuth.instance.currentUser;
      if (existingUser != null &&
          existingUser.email?.toLowerCase() == _emailController.text.trim().toLowerCase()) {
        // Already authenticated as this email — go directly to profile sync.
        user = existingUser;
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        user = credential.user;
      }

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-created',
          message: 'Unable to create user account.',
        );
      }

      // ── Step 2: Profile synchronization (idempotent) ────────────────────────
      // POST /api/users/profile creates or updates Users/{uid} and initializes
      // the wallet atomically. It is safe to call multiple times — retrying
      // will not create duplicates.
      try {
        await ApiClient.instance.post('/api/users/profile', body: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        });
      } on ApiException catch (e) {
        // Profile sync failed — Firebase Auth account exists but Firestore
        // profile was not created. Surface a recoverable error.
        if (!mounted) return;
        setState(() {
          _profileSyncFailed = true;
          _errorMessage =
              'Account created, but profile setup failed: ${e.message}\n'
              'Tap "Retry Setup" to try again.';
        });
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _profileSyncFailed = true;
          _errorMessage =
              'Account created, but profile setup failed due to a network error.\n'
              'Tap "Retry Setup" to try again.';
        });
        return;
      }

      if (!mounted) return;

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Registration failed. Please try again.';
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Retries only the profile synchronization step.
  /// Called when _profileSyncFailed is true — the Firebase Auth account
  /// already exists so we skip step 1 entirely.
  Future<void> _retryProfileSync() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _profileSyncFailed = false;
    });

    try {
      await ApiClient.instance.post('/api/users/profile', body: {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      });

      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      setState(() {
        _profileSyncFailed = true;
        _errorMessage =
            'Profile setup still failing: ${e.message}\n'
            'Tap "Retry Setup" to try again.';
      });
    } catch (_) {
      setState(() {
        _profileSyncFailed = true;
        _errorMessage =
            'Profile setup failed due to a network error.\n'
            'Tap "Retry Setup" to try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                      'Create Account',
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
                      'Register to access the canteen',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Full name ──────────────────────────────────────────
                    LabeledInputField(
                      key: AppKeys.registerNameField,
                      label: 'Full Name',
                      hint: 'Your full name',
                      icon: Icons.person_outline_rounded,
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Email ──────────────────────────────────────────────
                    LabeledInputField(
                      key: AppKeys.registerEmailField,
                      label: 'Email Address',
                      hint: 'you@example.com',
                      icon: Icons.mail_outline_rounded,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter your email';
                        if (!text.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Password ───────────────────────────────────────────
                    LabeledInputField(
                      key: AppKeys.registerPasswordField,
                      label: 'Password',
                      hint: 'At least 6 characters',
                      icon: Icons.lock_outline_rounded,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _register(),
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
                        final text = value ?? '';
                        if (text.isEmpty) return 'Enter your password';
                        if (text.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Error banner ───────────────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 32),

                    // ── Register / Retry button ────────────────────────────
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        key: AppKeys.registerSubmitButton,
                        onPressed: _isLoading
                            ? null
                            : _profileSyncFailed
                                ? _retryProfileSync
                                : _register,
                        child: _isLoading
                            ? const _ButtonSpinner()
                            : Text(_profileSyncFailed ? 'Retry Setup' : 'Create Account'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Sign in link ───────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.maybePop(context),
                          child: const Text('Sign In'),
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
