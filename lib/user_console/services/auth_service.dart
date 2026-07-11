import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  const AuthService._();

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return false;

    final data = userDoc.data();
    return (data?['isAdmin'] as bool?) ?? false;
  }

  /// Returns the user's current pickup PIN and the date it was last changed.
  /// Returns null for [pin] if none is set yet.
  static Future<({String? pin, DateTime? lastChanged})> getPickupPinInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return (pin: null, lastChanged: null);

    final doc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    final pin = data?['pickupPin'] as String?;
    final lastChangedTs = data?['lastPinChange'] as Timestamp?;
    return (pin: pin, lastChanged: lastChangedTs?.toDate());
  }

  /// Re-authenticates the user, checks the 30-day cooldown, then updates the
  /// pickup PIN in Firestore.
  ///
  /// Throws a descriptive [Exception] on failure.
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

    // ── Step 2: Check 30-day cooldown ───────────────────────────────────────
    final userRef = FirebaseFirestore.instance.collection('Users').doc(user.uid);
    final doc = await userRef.get();
    final lastChangedTs = doc.data()?['lastPinChange'] as Timestamp?;

    if (lastChangedTs != null) {
      final lastChanged = lastChangedTs.toDate();
      final diff = DateTime.now().difference(lastChanged).inDays;
      if (diff < 30) {
        final nextAllowed = lastChanged.add(const Duration(days: 30));
        final formatted =
            '${nextAllowed.day}/${nextAllowed.month}/${nextAllowed.year}';
        throw Exception(
          'PIN can only be changed once every 30 days.\nYou can change it again on $formatted.',
        );
      }
    }

    // ── Step 3: Update PIN ───────────────────────────────────────────────────
    await userRef.update({
      'pickupPin': newPin,
      'lastPinChange': FieldValue.serverTimestamp(),
    });
  }
}
