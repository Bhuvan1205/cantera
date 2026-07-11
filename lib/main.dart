import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'staff_console/screens/admin_dashboard_screen.dart';
import 'firebase_options.dart';
import 'user_console/screens/login_screen.dart';
import 'user_console/screens/main_screen.dart';
import 'theme/app_theme.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // ── Auth state loading ──────────────────────────────────────────────
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingApp();
        }

        final user = authSnapshot.data;

        // ── Not logged in → Login screen ────────────────────────────────────
        if (user == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            scrollBehavior: AppScrollBehavior(),
            theme: AppTheme.light,
            home: const LoginScreen(),
          );
        }

        // ── Logged in → fetch role then route ───────────────────────────────
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .get(),
          builder: (context, roleSnapshot) {
            // Still fetching role → show spinner
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingApp();
            }

            final data = roleSnapshot.data?.data();
            final isAdmin = (data?['isAdmin'] as bool?) ?? false;

            return MaterialApp(
              key: ValueKey(user.uid),
              debugShowCheckedModeBanner: false,
              scrollBehavior: AppScrollBehavior(),
              theme: AppTheme.light,
              home: isAdmin ? const AdminDashboardScreen() : const MainScreen(),
            );
          },
        );
      },
    );
  }
}

// ── Full-screen loading placeholder (used before MaterialApp is ready) ────────
class _LoadingApp extends StatelessWidget {
  const _LoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
