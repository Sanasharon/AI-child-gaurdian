// ============================================================
// main.dart (TEMPORARY DEBUG VERSION)
// ------------------------------------------------------------
// This version bypasses Firebase AuthGate logic and always
// shows the LoginScreen directly.
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AIChildGuardianApp());
}

class AIChildGuardianApp extends StatelessWidget {
  const AIChildGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Child Guardian',
      debugShowCheckedModeBanner: false,
      theme: AppDecorations.themeData(),
      home: const AuthGate(),
    );
  }
}

// ------------------------------------------------------------
// TEMPORARY AuthGate
// This bypasses authentication and Firestore completely and
// always opens LoginScreen.
// ------------------------------------------------------------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}