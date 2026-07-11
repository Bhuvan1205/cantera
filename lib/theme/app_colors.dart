import 'package:flutter/material.dart';

/// Centralized color token registry for the Premium Organic design system.
///
/// **Usage:** Import this file wherever a color is needed.
/// Never hard-code hex values in widget files — always reference a token here.
///
/// **Naming convention:**
///   - Surface tokens:  [bg], [cardBg], [summaryCard]
///   - Brand tokens:    [primary], [accent]
///   - Text tokens:     [textPrimary], [textMuted]
///   - Semantic tokens: [error], [errorBg], [success]
///   - Border tokens:   [border]
abstract final class AppColors {
  // ── Surface / Background ──────────────────────────────────────────────────

  /// Warm ivory — used as the page-level scaffold background.
  static const Color bg = Color(0xFFF9F5EF);

  /// Near-white parchment — used for card and input field surfaces.
  static const Color cardBg = Color(0xFFFFFDF9);

  /// Linen — used for order summary / totals section backgrounds.
  static const Color summaryCard = Color(0xFFF2EBE0);

  // ── Brand ─────────────────────────────────────────────────────────────────

  /// Forest green — primary buttons, headings, active nav, brand icon.
  static const Color primary = Color(0xFF0F382B);

  /// Clay brown — secondary actions, accent links.
  static const Color accent = Color(0xFF5B3F2B);

  /// Terracotta — earthy light clay orange, secondary brand accent.
  static const Color terracotta = Color(0xFFDFB088);


  // ── Text ──────────────────────────────────────────────────────────────────

  /// Same as [primary] — kept separate for semantic clarity in text contexts.
  static const Color textPrimary = Color(0xFF0F382B);

  /// Warm slate — subtitles, placeholders, secondary labels.
  static const Color textMuted = Color(0xFF5A6660);

  // ── Borders & Dividers ────────────────────────────────────────────────────

  /// Parchment border — used on cards, inputs, and dividers.
  static const Color border = Color(0xFFEFECE6);

  // ── Semantic ──────────────────────────────────────────────────────────────

  /// Error red — form validation, destructive states.
  static const Color error = Color(0xFFC94A4A);

  /// Tinted error background — used in inline error banners.
  static const Color errorBg = Color(0xFFFCECEC);

  /// Error banner border.
  static const Color errorBorder = Color(0xFFF5C6C6);

  /// Success / eco green — eco fee, success states.
  static const Color success = Color(0xFF3A7D5E);
}
