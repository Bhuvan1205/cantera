import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
      final idTokenResult = await user.getIdTokenResult();
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
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
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


}

