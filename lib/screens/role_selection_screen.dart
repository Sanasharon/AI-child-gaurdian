// ============================================================
// role_selection_screen.dart
// ------------------------------------------------------------
// Shown once, right after signup. The user picks whether this
// device/account is a PARENT or a CHILD. We save that choice
// into the "users" Firestore collection.
//
// If they pick Child, we also ask for the 6-digit link code
// that a parent should have shared with them, so the two
// accounts get connected (parent-child linking).
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_card.dart';
import 'parent_dashboard_screen.dart';
import 'child_dashboard_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String uid;
  final String email;

  const RoleSelectionScreen({super.key, required this.uid, required this.email});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _linkCodeController = TextEditingController();

  String? _selectedRole; // "parent" or "child"
  bool _isLoading = false;
  String? _errorText;

  // Generates a random 6-digit code for parents to share with their child.
  String _generateLinkCode() {
    final rand = Random();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  Future<void> _continue() async {
    if (_selectedRole == null || _nameController.text.trim().isEmpty) {
      setState(() => _errorText = 'Please select a role and enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final linkCode = _selectedRole == 'parent' ? _generateLinkCode() : null;

      final newUser = AppUser(
        uid: widget.uid,
        name: _nameController.text.trim(),
        email: widget.email,
        role: _selectedRole!,
        linkCode: linkCode,
      );

      // Save the profile document to Firestore -> users/{uid}
      await _firestoreService.createUserProfile(newUser);

      // If Child, link them to their parent using the entered code.
      if (_selectedRole == 'child') {
        if (_linkCodeController.text.trim().isEmpty) {
          throw Exception('Please enter the link code shared by your parent');
        }
        await _firestoreService.linkChildToParent(
          childUid: widget.uid,
          linkCode: _linkCodeController.text.trim(),
        );
      }

      if (!mounted) return;

      if (_selectedRole == 'parent') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ParentDashboardScreen(user: newUser)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ChildDashboardScreen(user: newUser)),
        );
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text('Who are you?', style: AppTextStyles.heading),
                const SizedBox(height: 6),
                Text('Select your role to personalize the app',
                    style: AppTextStyles.subheading),
                const SizedBox(height: 28),

                // ---- Role cards ----
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.family_restroom_rounded,
                        label: 'Parent',
                        selected: _selectedRole == 'parent',
                        onTap: () => setState(() => _selectedRole = 'parent'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.emoji_people_rounded,
                        label: 'Child',
                        selected: _selectedRole == 'child',
                        onTap: () => setState(() => _selectedRole = 'child'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ---- Name field ----
                Container(
                  decoration: AppDecorations.neumorphicInset(radius: 18),
                  child: TextField(
                    controller: _nameController,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.textLight),
                      hintText: 'Your full name',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    ),
                  ),
                ),

                // ---- Link code field (Child only) ----
                if (_selectedRole == 'child') ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: AppDecorations.neumorphicInset(radius: 18),
                    child: TextField(
                      controller: _linkCodeController,
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.link_rounded, color: AppColors.textLight),
                        hintText: 'Enter parent\'s link code',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                      ),
                    ),
                  ),
                ],

                if (_errorText != null) ...[
                  const SizedBox(height: 14),
                  Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],

                const SizedBox(height: 28),
                CustomButton(label: 'Continue', isLoading: _isLoading, onPressed: _continue),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Small reusable card used only within this screen for role picking.
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: selected
            ? AppDecorations.neumorphicInset(radius: 20).copyWith(
                color: AppColors.primary.withOpacity(0.15),
              )
            : AppDecorations.neumorphicCard(radius: 20),
        child: Column(
          children: [
            Icon(icon, size: 34, color: selected ? AppColors.primaryDark : AppColors.textLight),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primaryDark : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
