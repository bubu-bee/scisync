import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_navigation.dart';
import 'login_or_register.dart'; // <-- 1. Import the new Toggle Screen!

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // This stream constantly listens to Firebase Auth.
      // If a user logs in, it fires. If they log out, it fires.
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a quick loading spinner while Firebase checks the user's status on startup
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        }

        // If Firebase says "Yes, someone is logged in!" -> Send them to the main app
        if (snapshot.hasData && snapshot.data != null) {
          return const AppNavigation();
        }

        // <-- 2. Change the fallback to the Toggle Screen -->
        // If Firebase says "No one is logged in" -> Force them to the Switcher
        return const LoginOrRegister();
      },
    );
  }
}
