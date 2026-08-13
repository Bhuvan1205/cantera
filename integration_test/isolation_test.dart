import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:canteen_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:canteen_app/firebase_options.dart';
import 'package:canteen_app/user_console/services/auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('User A logout to User B isolates cached state and listeners', (WidgetTester tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Clear state before starting
    if (FirebaseAuth.instance.currentUser != null) {
      await AuthService.signOut();
    }

    final userAEmail = 'usera_${DateTime.now().millisecondsSinceEpoch}@test.com';
    final userBEmail = 'userb_${DateTime.now().millisecondsSinceEpoch}@test.com';
    const password = 'password123';

    // 1. Create User A
    final credA = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: userAEmail, password: password);
    expect(credA.user, isNotNull);
    final uidA = credA.user!.uid;

    // Run the app (MaterialApp should build with User A)
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Wait for the app to settle and verify User A is active
    expect(FirebaseAuth.instance.currentUser?.uid, uidA);

    // Grab the current widget tree state (MaterialApp key)
    final materialAppFinder = find.byType(MaterialApp);
    expect(materialAppFinder, findsWidgets);
    final materialApp1 = tester.widget<MaterialApp>(materialAppFinder.last);
    final keyA = materialApp1.key;

    // 2. Logout User A
    await AuthService.signOut();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(FirebaseAuth.instance.currentUser, isNull);

    // 3. Create/Login User B
    final credB = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: userBEmail, password: password);
    expect(credB.user, isNotNull);
    final uidB = credB.user!.uid;

    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(FirebaseAuth.instance.currentUser?.uid, uidB);

    // Grab the new widget tree state (MaterialApp key)
    final materialAppFinder2 = find.byType(MaterialApp);
    final materialApp2 = tester.widget<MaterialApp>(materialAppFinder2.last);
    final keyB = materialApp2.key;

    // 4. Verify Isolation
    // The key of MaterialApp must have changed, which forces Flutter to completely
    // destroy and recreate the widget tree, tearing down all old StreamBuilders,
    // Providers, and cached state associated with User A.
    expect(keyA, isNot(equals(keyB)), reason: "MaterialApp key must change to destroy all old state");

    // Clean up User B
    await AuthService.signOut();
  });
}
