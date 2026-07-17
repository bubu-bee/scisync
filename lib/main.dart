import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'features/ui_shell/app_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The Safety Blanket (try-catch)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      // This points straight to your new navigation bar!
      home: const AppNavigation(),
    );
  }
}
