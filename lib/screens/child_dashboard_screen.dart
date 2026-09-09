// ============================================================
// child_dashboard_screen.dart
// ------------------------------------------------------------
// Child Mode home screen. Responsibilities:
//   - Ask for GPS permission as soon as the screen opens.
//   - Start background location tracking (every 10s -> Firestore).
//   - Show a large, unmissable SOS button that writes an
//     emergency alert (with current GPS position) to Firestore.
// ============================================================

import 'dart:async';
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
  bool _isSendingSafeRequest = false;
  String? _statusMessage;
  bool _isLocationPaused = false;
  StreamSubscription? _safetySubscription;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    _listenToSafetyRequests();
  }

  @override
  void dispose() {
    _safetySubscription?.cancel();
    _locationService.stopTracking();
    super.dispose();
  }

  void _listenToSafetyRequests() {
    _safetySubscription = _firestoreService.streamSafetyRequest(widget.user.uid).listen((data) {
      if (!mounted) return;
      final status = data?['status'] as String?;
      if (status == 'approved') {
        if (!_isLocationPaused) {
          _locationService.stopTracking();
          setState(() {
            _isLocationPaused = true;
            _statusMessage = "You're marked safe — location sharing paused.";
          });
        }
      } else if (status == 'rejected') {
        if (_isLocationPaused || _isSendingSafeRequest) {
          // Parent rejected -> resume or keep tracking active
          _locationService.startTracking(widget.user.uid);
          setState(() {
            _isLocationPaused = false;
            _statusMessage = 'Safety pause was not approved by parent. Live tracking active.';
          });
        }
      } else if (status == 'pending') {
        setState(() {
          _statusMessage = 'Waiting for parent approval...';
        });
      } else {
        // null or cancelled
        if (_isLocationPaused) {
          _locationService.startTracking(widget.user.uid);
          setState(() {
            _isLocationPaused = false;
            _statusMessage = 'Live location tracking is ON.';
          });
        }
      }
    });
  }

  // Requests permission then starts sending GPS updates every 10s.
  Future<void> _initLocationTracking() async {
    final granted = await _locationService.requestPermission();
    if (!granted) {
      setState(() => _statusMessage = 'Location permission is required for safety tracking.');
      return;
    }
    if (!_isLocationPaused) {
      _locationService.startTracking(widget.user.uid);
      setState(() => _statusMessage = 'Live location tracking is ON.');
    }
  }

  // Called when "🟢 I'm Safe" button is pressed.
  Future<void> _handleImSafe() async {
    setState(() => _isSendingSafeRequest = true);
    try {
      await _firestoreService.createSafetyRequest(
        childUid: widget.user.uid,
        childName: widget.user.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safety request sent to parent. Waiting for approval...'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send safety request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingSafeRequest = false);
    }
  }

  // Called when the big red SOS button is pressed.
  Future<void> _sendSos() async {
    setState(() => _isSendingSos = true);
    try {
      // SOS must always work, even when location sharing is paused.
      // If triggered while paused, resume location sharing immediately.
      if (_isLocationPaused) {
        await _firestoreService.resetSafetyRequest(widget.user.uid);
        _locationService.startTracking(widget.user.uid);
        setState(() {
          _isLocationPaused = false;
          _statusMessage = 'Live location tracking is ON.';
        });
      }

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
              child: _navIndex == 2
                  ? _buildProfileScreen()
                  : StreamBuilder<Map<String, dynamic>?>(
                      stream: _firestoreService.streamSafetyRequest(widget.user.uid),
                      builder: (context, safetySnap) {
                        final safetyData = safetySnap.data;
                        final safetyStatus = safetyData?['status'] as String?;
                        final isPending = safetyStatus == 'pending';
                        final isApproved = safetyStatus == 'approved';

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final double shortestSide = MediaQuery.of(context).size.shortestSide;
                            final double availableHeight = constraints.maxHeight;
                            final double dynamicMax = (availableHeight * 0.34).clamp(120.0, 200.0);
                            final double sosSize = (shortestSide / 2.3).clamp(120.0, dynamicMax);

                            String displayStatus = _statusMessage ?? 'Starting location services...';
                            if (isPending) {
                              displayStatus = 'Waiting for parent approval...';
                            } else if (isApproved) {
                              displayStatus = "You're marked safe — location sharing paused.";
                            }

                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - 16 > 0 ? constraints.maxHeight - 16 : 0,
                                ),
                                child: IntrinsicHeight(
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 6),

                                      // ---- Status card ----
                                      CustomCard(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isApproved
                                                  ? Icons.pause_circle_filled_rounded
                                                  : isPending
                                                      ? Icons.hourglass_top_rounded
                                                      : Icons.gps_fixed_rounded,
                                              color: isApproved ? AppColors.success : AppColors.primary,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                displayStatus,
                                                style: AppTextStyles.body,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const Spacer(),
                                      const SizedBox(height: 10),

                                      // ---- Big SOS button ----
                                      Text(
                                        'In an emergency, tap the button below',
                                        style: AppTextStyles.subheading,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 14),
                                      GestureDetector(
                                        onTap: _isSendingSos ? null : _sendSos,
                                        child: Container(
                                          width: sosSize,
                                          height: sosSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.danger,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.danger.withOpacity(0.5),
                                                blurRadius: 28,
                                                spreadRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: _isSendingSos
                                                ? const CircularProgressIndicator(color: Colors.white)
                                                : Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.sos_rounded, color: Colors.white, size: (sosSize * 0.28).clamp(32.0, 48.0)),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'SOS',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: (sosSize * 0.16).clamp(18.0, 26.0),
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      // ---- "🟢 I'm Safe" Button ----
                                      if (isApproved)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: AppDecorations.neumorphicInset(radius: 16),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                "You're marked safe",
                                                style: TextStyle(
                                                  color: AppColors.success,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed: (isPending || _isSendingSafeRequest) ? null : _handleImSafe,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.success,
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: _isSendingSafeRequest
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                  )
                                                : Text(
                                                    isPending ? '⏳ Waiting for parent approval' : "🟢 I'm Safe",
                                                    style: AppTextStyles.button.copyWith(fontSize: 15),
                                                  ),
                                          ),
                                        ),

                                      const Spacer(),
                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
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

  // Profile tab for child: account and parent connection info
  Widget _buildProfileScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: CustomCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_rounded, size: 40, color: AppColors.primaryDark),
              const SizedBox(height: 16),
              Text(widget.user.name, style: AppTextStyles.heading.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              Text(widget.user.email, style: AppTextStyles.subheading.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              Text(
                'Role: Child\nConnected Parent: ${widget.user.linkedUid != null ? "Connected" : "Not Linked"}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String subtitle = 'Child Mode';
    if (_navIndex == 2) {
      subtitle = 'Child Profile';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hi, ${widget.user.name}',
                  style: AppTextStyles.heading.copyWith(fontSize: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.subheading.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
