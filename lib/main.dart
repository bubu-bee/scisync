import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import your new Auth Wrapper!
import 'features/ui_shell/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The Safety Blanket (try-catch)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SciSync',
      debugShowCheckedModeBanner: false, // Hides the red "DEBUG" sticker
      theme: ThemeData(
        // Set the app's main color to Teal to match your modern UI
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // The crucial change: Start the app at the Wrapper, NOT AppNavigation
      home: const AuthWrapper(),
    );
  }
}
