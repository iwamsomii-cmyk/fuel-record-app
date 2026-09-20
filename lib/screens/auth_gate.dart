import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'pending_approval_screen.dart';
import 'home_screen.dart';

/// Decides which screen to show based on auth + approval state:
/// not signed in -> LoginScreen
/// signed in but not approved yet -> PendingApprovalScreen
/// signed in and approved -> HomeScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.instance.authStateChanges,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!authSnap.hasData) {
          return const LoginScreen();
        }
        return StreamBuilder(
          stream: AuthService.instance.watchMyApprovalStatus(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            final data = userSnap.data?.data();
            final approved = data != null && data['approved'] == true;
            if (!approved) {
              return const PendingApprovalScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}