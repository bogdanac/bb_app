import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'security_service.dart';

class AuthWrapper extends StatelessWidget {
  final Widget? authenticatedHome;

  const AuthWrapper({super.key, this.authenticatedHome});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in, check IP and track access
          SecurityService().trackAccess();
          // Use provided home or navigate back to let InitialScreen handle it
          return authenticatedHome ?? const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is not signed in
        return const LoginScreen();
      },
    );
  }
}
