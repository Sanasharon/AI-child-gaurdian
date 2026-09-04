// ============================================================
// login_screen.dart
// ------------------------------------------------------------
// The first screen the user sees. Lets them either LOG IN to
// an existing account or SIGN UP for a new one, using Firebase
// Authentication (email + password).
//
// On successful signup, we DON'T yet know if the user is a
// Parent or a Child - so we send them to RoleSelectionScreen
// to choose. On login, we look up their saved role and skip
// straight to the correct dashboard.
// ============================================================

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import 'role_selection_screen.dart';
import 'parent_dashboard_screen.dart';
import 'child_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isSignUp = false; // toggles between Login / Sign Up mode
  bool _isLoading = false;
  String? _errorText;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      if (_isSignUp) {
        // Create a brand-new Firebase Auth account.
        final user = await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (user != null && mounted) {
          // New users always go pick a role next.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => RoleSelectionScreen(uid: user.uid, email: user.email ?? '')),
          );
        }
      } else {
        // Log in to an existing account.
        final user = await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (user != null && mounted) {
          // Look up their saved profile to know their role.
          final profile = await _firestoreService.getUserProfile(user.uid);
          if (profile == null) {
            // Edge case: account exists in Auth but no Firestore
            // profile yet -> send them to role selection.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => RoleSelectionScreen(uid: user.uid, email: user.email ?? '')),
            );
          } else if (profile.role == 'parent') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => ParentDashboardScreen(user: profile)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => ChildDashboardScreen(user: profile)),
            );
          }
        }
      }
    } catch (e) {
      setState(() => _errorText = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // App logo / icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: AppDecorations.neumorphicCard(radius: 24),
                    child: const Icon(Icons.shield_moon_rounded,
                        color: AppColors.primaryDark, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text('AI Child Guardian', style: AppTextStyles.heading),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp ? 'Create your account to get started' : 'Welcome back, please login',
                    style: AppTextStyles.subheading,
                  ),
                  const SizedBox(height: 32),

                  // ---- Email field ----
                  _buildTextField(
                    controller: _emailController,
                    hint: 'Email address',
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),

                  // ---- Password field ----
                  _buildTextField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    obscure: true,
                  ),

                  if (_errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],

                  const SizedBox(height: 28),
                  CustomButton(
                    label: _isSignUp ? 'Sign Up' : 'Login',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 18),

                  // Toggle between Login / Sign up
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Login'
                            : "Don't have an account? Sign Up",
                        style: const TextStyle(color: AppColors.primaryDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Small helper to keep text fields styled consistently.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return Container(
      decoration: AppDecorations.neumorphicInset(radius: 18),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
          hintText: hint,
          hintStyle: AppTextStyles.subheading.copyWith(fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        ),
      ),
    );
  }
}
