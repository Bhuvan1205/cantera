import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// A label + [TextFormField] pair styled to the Premium Organic design system.
///
/// Encapsulates the pattern that was previously duplicated across
/// [LoginScreen] and [RegisterScreen] (`_buildLabel` + `_inputDecoration`).
///
/// **Usage:**
/// ```dart
/// LabeledInputField(
///   key: AppKeys.loginEmailField,
///   label: 'Email Address',
///   hint: 'you@example.com',
///   icon: Icons.mail_outline_rounded,
///   controller: _emailController,
///   keyboardType: TextInputType.emailAddress,
///   validator: (v) => v!.isEmpty ? 'Required' : null,
/// )
/// ```
class LabeledInputField extends StatelessWidget {
  const LabeledInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;

  /// Optional trailing widget (e.g., show/hide password button).
  final Widget? suffixIcon;

  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Field label ───────────────────────────────────────────────────
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),

        // ── Input field ───────────────────────────────────────────────────
        TextFormField(
          // NOTE: The [key] on this widget goes on the Column, not the
          // inner TextFormField. To target the field in tests, use:
          //   find.descendant(of: find.byKey(key), matching: find.byType(TextFormField))
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
      ],
    );
  }
}
