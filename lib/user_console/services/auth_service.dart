import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/services/api_client.dart';
import '../../core/services/fcm_service.dart';

class AuthService {
  const AuthService._();

  static Future<void> signOut() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        try {
          await FcmService.instance.deleteTokenFromBackend(token);
        } catch (_) {
          // Ignore backend failure; proceed to invalidate token on device
        }
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  /// Single Source of Truth for Staff/Admin privilege resolution in Flutter.
  /// Matches backend dual-layer verification:
  /// 1. Fast Path: Firebase Auth Custom Claims (role == 'admin' | 'staff', admin == true, staff == true)
  /// 2. Authoritative Fallback: Firestore Users/{uid} document (isAdmin == true, role == 'admin' | 'staff')
  static Future<bool> isCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Fast path: Custom Claims
    try {
      final idTokenResult = await user.getIdTokenResult().timeout(const Duration(seconds: 3));
      final customRole = idTokenResult.claims?['role'] as String?;
      final isAdminClaim = idTokenResult.claims?['admin'] as bool?;
      final isStaffClaim = idTokenResult.claims?['staff'] as bool?;
      if (customRole == 'admin' ||
          customRole == 'staff' ||
          isAdminClaim == true ||
          isStaffClaim == true) {
        return true;
      }
    } catch (_) {}

    // Fallback: Firestore document check
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get().timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final data = doc.data();
        final isAdmin = (data?['isAdmin'] as bool?) ?? false;
        final role = data?['role'] as String?;
        if (isAdmin == true || role == 'admin' || role == 'staff') {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Returns the user's current pickup PIN status and the date it was last changed.
  static Future<({String? pin, DateTime? lastChanged})> getPickupPinInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return (pin: null, lastChanged: null);

    try {
      final res = await ApiClient.instance.get('/api/users/me/pin') as Map<String, dynamic>;
      final lastChangedStr = res['last_pin_change'] as String?;
      DateTime? lastChanged;
      if (lastChangedStr != null) {
        lastChanged = DateTime.tryParse(lastChangedStr);
      }
      final hasPin = res['has_pin'] as bool? ?? false;
      return (pin: hasPin ? '****' : null, lastChanged: lastChanged);
    } catch (_) {
      return (pin: null, lastChanged: null);
    }
  }

  /// Re-authenticates the user, then updates the pickup PIN via FastAPI backend.
  /// Backend enforces 4-digit validation and 30-day cooldown.
  static Future<void> changePickupPin({
    required String password,
    required String newPin,
  }) async {
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      throw Exception('PIN must be exactly 4 digits.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in.');
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception('No email associated with this account.');
    }

    // ── Step 1: Re-authenticate ──────────────────────────────────────────────
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect password. Please try again.');
      }
      throw Exception('Authentication failed: ${e.message}');
    }

    // ── Step 2: Update PIN via Backend (atomic cooldown check) ───────────────
    try {
      await ApiClient.instance.post('/api/users/change-pin', body: {
        'new_pin': newPin,
      });
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }
}
