// ============================================================
// parent_dashboard_screen.dart
// ------------------------------------------------------------
// Parent Mode home screen. Shows:
//   - A Google Map with a live marker for the child's location
//     (updates automatically via a Firestore stream).
//   - Quick stat cards (last updated time, SOS status).
//   - A bottom nav bar (Map / Alerts / Profile placeholders).
//
// NOTE: This screen expects the parent's account to already be
// linked to a child (see role_selection_screen.dart). If not
// linked yet, it shows a friendly "waiting for child" message.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/sos_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/bottom_nav_bar.dart';
import 'login_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  final AppUser user;
  const ParentDashboardScreen({super.key, required this.user});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  int _navIndex = 0;
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final childUid = widget.user.linkedUid;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: childUid == null
                  ? _buildWaitingForChild()
                  : _buildLinkedDashboard(childUid),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          NavItem(icon: Icons.map_rounded, label: 'Map'),
          NavItem(icon: Icons.notifications_active_rounded, label: 'Alerts'),
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
                Text('Hello, ${widget.user.name}', style: AppTextStyles.heading.copyWith(fontSize: 20)),
                Text('Parent Dashboard', style: AppTextStyles.subheading.copyWith(fontSize: 13)),
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

  // Shown if the parent hasn't linked a child account yet.
  Widget _buildWaitingForChild() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: CustomCard(
          child: Column(
            children: [
              const Icon(Icons.link_off_rounded, size: 40, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text('No child linked yet', style: AppTextStyles.heading.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                'Share your link code "${widget.user.linkCode}" with your child\'s app to connect.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Main dashboard once a child is linked: map + stats + SOS alerts.
  Widget _buildLinkedDashboard(String childUid) {
    return StreamBuilder<LocationModel?>(
      stream: _firestoreService.streamChildLocation(childUid),
      builder: (context, locationSnapshot) {
        final location = locationSnapshot.data;

        return Column(
          children: [
            // ---------------- MAP ----------------
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: AppDecorations.neumorphicCard(radius: 26),
                  child: location == null
                      ? const Center(child: Text('Waiting for child\'s location...'))
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(location.latitude, location.longitude),
                            zoom: 15,
                          ),
                          onMapCreated: (controller) => _mapController = controller,
                          markers: {
                            Marker(
                              markerId: const MarkerId('child'),
                              position: LatLng(location.latitude, location.longitude),
                              infoWindow: const InfoWindow(title: 'Child\'s current location'),
                            ),
                          },
                        ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ---------------- STATS ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.access_time_rounded,
                      label: 'Last Updated',
                      value: location == null
                          ? '--'
                          : _formatTime(location.timestamp),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: StreamBuilder<List<SosAlert>>(
                      stream: _firestoreService.streamActiveAlerts(childUid),
                      builder: (context, alertSnapshot) {
                        final activeAlerts = alertSnapshot.data ?? [];
                        final hasAlert = activeAlerts.isNotEmpty;
                        return StatTile(
                          icon: hasAlert ? Icons.warning_rounded : Icons.shield_rounded,
                          label: hasAlert ? 'SOS ACTIVE!' : 'All Safe',
                          value: hasAlert ? '${activeAlerts.length}' : 'OK',
                          iconColor: hasAlert ? AppColors.danger : AppColors.success,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
