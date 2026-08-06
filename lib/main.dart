import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'staff_console/screens/admin_dashboard_screen.dart';
import 'firebase_options.dart';
import 'user_console/screens/login_screen.dart';
import 'user_console/screens/main_screen.dart';
import 'user_console/services/auth_service.dart';
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

  debugPrint('========================================');
  debugPrint('[Startup] kIsWeb: $kIsWeb');
  debugPrint('[Startup] defaultTargetPlatform: $defaultTargetPlatform');
  debugPrint('[Startup] AppConfig.backendBaseUrl: ${AppConfig.backendBaseUrl}');
  debugPrint('========================================');

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

        // ── Logged in → fetch role then route (Single Source of Truth) ──────
        return FutureBuilder<bool>(
          future: AuthService.isCurrentUserAdmin(),
          builder: (context, roleSnapshot) {
            // Still fetching role → show spinner
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingApp();
            }

            final isStaffOrAdmin = roleSnapshot.data ?? false;

            return MaterialApp(
              key: ValueKey('${user.uid}_$isStaffOrAdmin'),
              debugShowCheckedModeBanner: false,
              scrollBehavior: AppScrollBehavior(),
              theme: AppTheme.light,
              home: isStaffOrAdmin
                  ? const AdminDashboardScreen()
                  : const MainScreen(),
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
