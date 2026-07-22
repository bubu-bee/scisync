import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'registration_screen.dart';

class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  // Initially, we show the login page
  bool showLoginPage = true;

  // This function flips the switch!
  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      // Pass the function to the Login screen
      return LoginScreen(onTap: togglePages);
    } else {
      // Pass the function to the Registration screen
      return RegistrationScreen(onTap: togglePages);
    }
  }
}
