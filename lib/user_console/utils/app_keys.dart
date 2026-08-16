import 'package:flutter/widgets.dart';

/// Centralized widget key registry for the Canteen App.
///
/// **Purpose:** Every interactive or structurally significant widget in the
/// app should carry a [Key] from this registry. This enables:
///
///   1. **Widget Inspector** — Find any widget instantly in Flutter DevTools
///      by searching for its key name.
///   2. **Widget Tests** — Locate widgets reliably via `find.byKey(AppKeys.x)`.
///   3. **Crash Reports** — Stack traces can reference meaningful identifiers
///      rather than anonymous widget indices.
///   4. **Hot Reload Stability** — Keys ensure Flutter reconciles stateful
///      widgets correctly across rebuilds.
///
/// **Naming convention:** `<screen>_<element>`
///   e.g. `login_email_field`, `cart_place_order_button`
///
/// **Usage:**
/// ```dart
/// TextFormField(key: AppKeys.loginEmailField, ...)
/// ElevatedButton(key: AppKeys.loginSubmitButton, ...)
/// ```
abstract final class AppKeys {
  static const Key groupOrderCard = Key('group_order_card');
  static const Key groupOrderJoinField = Key('group_order_join_field');
  // ── Login Screen ─────────────────────────────────────────────────────────
  static const Key loginEmailField    = Key('login_email_field');
  static const Key loginPasswordField = Key('login_password_field');
  static const Key loginSubmitButton  = Key('login_submit_button');
  static const Key loginRegisterLink  = Key('login_register_link');

  // ── Register Screen ───────────────────────────────────────────────────────
  static const Key registerNameField     = Key('register_name_field');
  static const Key registerEmailField    = Key('register_email_field');
  static const Key registerPasswordField = Key('register_password_field');
  static const Key registerSubmitButton  = Key('register_submit_button');

  // ── Menu Screen ───────────────────────────────────────────────────────────
  static const Key menuSearchField = Key('menu_search_field');
  static const Key menuItemList    = Key('menu_item_list');

  // ── Cart / Review Order Screen ────────────────────────────────────────────
  static const Key cartItemList         = Key('cart_item_list');
  static const Key cartPlaceOrderButton = Key('cart_place_order_button');

  // ── Order Detail Screen ───────────────────────────────────────────────────
  static const Key orderDetailQrButton      = Key('order_detail_qr_button');
  static const Key orderDetailReceiptButton = Key('order_detail_receipt_button');
  static const Key orderDetailSummaryCard   = Key('order_detail_summary_card');

  // ── Order History Screen ──────────────────────────────────────────────────
  static const Key orderHistoryList = Key('order_history_list');

  // ── Profile Screen ────────────────────────────────────────────────────────
  static const Key profileSignOutButton  = Key('profile_sign_out_button');
  static const Key profileScannerButton  = Key('profile_scanner_button');
  static const Key profileNameCard       = Key('profile_name_card');
  static const Key profileEmailCard      = Key('profile_email_card');

  // ── QR Screen ─────────────────────────────────────────────────────────────
  static const Key qrCodeView           = Key('qr_code_view');
  static const Key qrDeactivatedView    = Key('qr_deactivated_view');

  // ── Bottom Navigation Bar ─────────────────────────────────────────────────
  static const Key navHomeTab   = Key('nav_home_tab');
  static const Key navOrdersTab = Key('nav_orders_tab');
  static const Key navCartTab   = Key('nav_cart_tab');

  // ── Wallet Screen ─────────────────────────────────────────────────────────
  static const Key walletBalanceCard      = Key('wallet_balance_card');
  static const Key walletAddMoneyButton   = Key('wallet_add_money_button');
  static const Key walletViewAllButton    = Key('wallet_view_all_button');

  // ── Add Money Screen ──────────────────────────────────────────────────────
  static const Key addMoneyAmountField    = Key('add_money_amount_field');
  static const Key addMoneySubmitButton   = Key('add_money_submit_button');

  // ── Cart — Payment Method Selector ────────────────────────────────────────
  static const Key paymentMethodSelector  = Key('payment_method_selector');

  // ── Order Detail — Refund ─────────────────────────────────────────────────
  static const Key orderRefundButton      = Key('order_refund_button');

  // ── Profile — Wallet Entry ────────────────────────────────────────────────
  static const Key profileWalletCard      = Key('profile_wallet_card');

  // ── Shared / Generic ─────────────────────────────────────────────────────
  /// Used on loading spinners when no more specific key applies.
  static const Key loadingIndicator = Key('loading_indicator');

  /// Used on empty-state widgets.
  static const Key emptyStateView = Key('empty_state_view');
}
