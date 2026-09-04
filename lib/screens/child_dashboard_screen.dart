// ============================================================
// child_dashboard_screen.dart
// ------------------------------------------------------------
// Child Mode home screen. Responsibilities:
//   - Ask for GPS permission as soon as the screen opens.
//   - Start background location tracking (every 10s -> Firestore).
//   - Show a large, unmissable SOS button that writes an
//     emergency alert (with current GPS position) to Firestore.
// ============================================================

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/sos_model.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/bottom_nav_bar.dart';
import 'login_screen.dart';

class ChildDashboardScreen extends StatefulWidget {
  final AppUser user;
  const ChildDashboardScreen({super.key, required this.user});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  final _locationService = LocationService();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  int _navIndex = 0;
  bool _isSendingSos = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
  }

  @override
  void dispose() {
    // Stop the 10-second GPS timer when this screen closes.
    _locationService.stopTracking();
    super.dispose();
  }

  // Requests permission then starts sending GPS updates every 10s.
  Future<void> _initLocationTracking() async {
    final granted = await _locationService.requestPermission();
    if (!granted) {
      setState(() => _statusMessage = 'Location permission is required for safety tracking.');
      return;
    }
    _locationService.startTracking(widget.user.uid);
    setState(() => _statusMessage = 'Live location tracking is ON.');
  }

  // Called when the big red SOS button is pressed.
  Future<void> _sendSos() async {
    setState(() => _isSendingSos = true);
    try {
      final position = await _locationService.getCurrentPosition();
      final alert = SosAlert(
        childUid: widget.user.uid,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );
      await _firestoreService.createSosAlert(alert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 SOS alert sent to your parent!'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingSos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // ---- Status card ----
                    CustomCard(
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed_rounded, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMessage ?? 'Starting location services...',
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ---- Big SOS button ----
                    Text('In an emergency, tap the button below',
                        style: AppTextStyles.subheading, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isSendingSos ? null : _sendSos,
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.danger,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.danger.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isSendingSos
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.sos_rounded, color: Colors.white, size: 48),
                                    SizedBox(height: 8),
                                    Text(
                                      'SOS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          NavItem(icon: Icons.home_rounded, label: 'Home'),
          NavItem(icon: Icons.shield_rounded, label: 'Safety'),
          NavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, ${widget.user.name}', style: AppTextStyles.heading.copyWith(fontSize: 20)),
                Text('Child Mode', style: AppTextStyles.subheading.copyWith(fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await _authService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: AppDecorations.neumorphicCard(radius: 14),
              child: const Icon(Icons.logout_rounded, size: 20, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
