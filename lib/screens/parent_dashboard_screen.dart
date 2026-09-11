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

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/sos_model.dart';
import '../models/safe_place_model.dart';
import '../models/geofence_event_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/geofence_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/marker_helper.dart';
import 'login_screen.dart';
import 'safe_places_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  final AppUser user;
  const ParentDashboardScreen({super.key, required this.user});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _geofenceService = GeofenceService();
  int _navIndex = 0;
  GoogleMapController? _mapController;

  // Track previous and current locations for the trail visualization
  LocationModel? _previousLocation;
  LocationModel? _currentLocation;
  BitmapDescriptor? _childPinMarkerIcon;
  BitmapDescriptor? _darkBlueMarkerIcon;
  BitmapDescriptor? _arrowIcon;

  // Cached active safe places
  List<SafePlace> _activeSafePlaces = [];

  @override
  void initState() {
    super.initState();
    _initCustomMarkers();
  }

  void _processGeofenceForLocation(String childUid, LocationModel location) {
    if (_activeSafePlaces.isEmpty) return;

    // Evaluate active geofences on every location change
    for (final place in _activeSafePlaces) {
      final event = _geofenceService.evaluateLocation(
        monitoredUid: childUid,
        place: place,
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        timestamp: location.timestamp,
      );

      if (event != null) {
        _firestoreService.recordGeofenceEvent(event);
      }
    }
  }

  Future<void> _initCustomMarkers() async {
    _childPinMarkerIcon = await MarkerHelper.createMinimalWhitePinMarker();
    _darkBlueMarkerIcon = await _createCircleMarker(
      color: const Color(0xFF1E3A8A), // Dark blue
      borderColor: const Color(0xFF93C5FD), // Subtle lighter blue border
      radius: 14, // Slightly smaller than current
      borderWidth: 3.5,
    );
    _arrowIcon = await _createArrowMarker();
    if (mounted) setState(() {});
  }



  Future<BitmapDescriptor> _createCircleMarker({
    required Color color,
    required Color borderColor,
    required double radius,
    required double borderWidth,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = (radius + borderWidth + 4) * 2;
    final center = Offset(size / 2, size / 2);

    // Subtle drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + const Offset(0, 1.5), radius + borderWidth, shadowPaint);

    // Outer border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + borderWidth, borderPaint);

    // Inner circle
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, innerPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createArrowMarker() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = 36.0;

    final paint = Paint()
      ..color = const Color(0xFF60A5FA) // Light subtle blue arrow on dark map
      ..style = PaintingStyle.fill;

    // Draw an arrow pointing upwards (0 deg / North)
    final path = Path();
    path.moveTo(size / 2, 6); // tip
    path.lineTo(size - 6, size - 8);
    path.lineTo(size / 2, size - 14);
    path.lineTo(6, size - 8);
    path.close();

    // Subtle drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  double _calculateBearing(double startLat, double startLng, double endLat, double endLng) {
    final double startLatRad = startLat * (math.pi / 180.0);
    final double startLngRad = startLng * (math.pi / 180.0);
    final double endLatRad = endLat * (math.pi / 180.0);
    final double endLngRad = endLng * (math.pi / 180.0);

    final double dLng = endLngRad - startLngRad;
    final double y = math.sin(dLng) * math.cos(endLatRad);
    final double x = math.cos(startLatRad) * math.sin(endLatRad) -
        math.sin(startLatRad) * math.cos(endLatRad) * math.cos(dLng);

    final double bearingRad = math.atan2(y, x);
    final double bearingDeg = (bearingRad * (180.0 / math.pi) + 360.0) % 360.0;
    return bearingDeg;
  }

  String _formatTimeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 45) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      return '$m min${m > 1 ? "s" : ""} ago';
    } else if (difference.inHours < 24) {
      final h = difference.inHours;
      return '$h hour${h > 1 ? "s" : ""} ago';
    } else {
      final d = difference.inDays;
      return '$d day${d > 1 ? "s" : ""} ago';
    }
  }

  void _updateLocationTrail(LocationModel newLocation) {
    if (_currentLocation == null) {
      _currentLocation = newLocation;
    } else {
      // Calculate distance between current and new location
      final double distance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );

      // Filter GPS noise: only register new movement if child moved at least 5 meters
      if (distance >= 5.0) {
        _previousLocation = _currentLocation;
        _currentLocation = newLocation;
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              // Listen to the parent's OWN profile in real time instead of
              // the one-time snapshot captured at login. This way, if the
              // child links to this parent AFTER the parent already opened
              // the dashboard, "linkedUid" updates live and the map below
              // connects automatically without requiring a re-login.
              child: StreamBuilder<AppUser?>(
                stream: _firestoreService.streamUserProfile(widget.user.uid),
                builder: (context, profileSnapshot) {
                  final parentProfile = profileSnapshot.data ?? widget.user;
                  final childUid = parentProfile.linkedUid;
                  if (childUid == null) {
                    return _buildWaitingForChild();
                  }

                  if (_navIndex == 1) {
                    return _buildHistoryScreen(childUid);
                  } else if (_navIndex == 2) {
                    return _buildProfileScreen();
                  }

                  return _buildLinkedDashboard(childUid);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: (i) {
          if (_navIndex != i) {
            _mapController = null;
            setState(() => _navIndex = i);
          }
        },
        items: const [
          NavItem(icon: Icons.home_rounded, label: 'Home'),
          NavItem(icon: Icons.history_rounded, label: 'History'),
          NavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String subtitle = 'Parent Dashboard';
    if (_navIndex == 1) {
      subtitle = 'Safety History';
    } else if (_navIndex == 2) {
      subtitle = 'Parent Profile';
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
                  'Hello, ${widget.user.name}',
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

  // Shown if the parent hasn't linked a child account yet.
  Widget _buildWaitingForChild() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: CustomCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

  // Main dashboard once a child is linked: map + stats + Recent Activities.
  Widget _buildLinkedDashboard(String childUid) {
    return StreamBuilder<List<SafePlace>>(
      stream: _firestoreService.streamActiveSafePlaces(
        guardianUid: widget.user.uid,
        monitoredUid: childUid,
      ),
      builder: (context, safePlacesSnapshot) {
        final safePlaces = safePlacesSnapshot.data ?? [];
        _activeSafePlaces = safePlaces;

        return StreamBuilder<LocationModel?>(
          stream: _firestoreService.streamChildLocation(childUid),
          builder: (context, locationSnapshot) {
            final location = locationSnapshot.data;

            if (location != null) {
              _updateLocationTrail(location);
              _processGeofenceForLocation(childUid, location);
            }

            // Keep the map camera centered on the child as new GPS points
            // arrive from Firestore, instead of only centering once on the
            // very first location. Scheduled after the frame so the map
            // controller is never touched in the middle of a build.
            if (location != null && _mapController != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _mapController == null) return;
                try {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(LatLng(location.latitude, location.longitude)),
                  );
                } catch (_) {}
              });
            }

            final markers = <Marker>{};
            final polylines = <Polyline>{};
            final circles = <Circle>{};

            // Add Geofence circles for each active SafePlace
            for (final sp in safePlaces) {
              circles.add(
                Circle(
                  circleId: CircleId('geofence_${sp.id}'),
                  center: LatLng(sp.latitude, sp.longitude),
                  radius: sp.radius,
                  strokeColor: AppColors.primaryDark,
                  strokeWidth: 2,
                  fillColor: AppColors.primary.withValues(alpha: 0.18),
                ),
              );
            }

            if (location != null) {
              // Current child location marker (minimal white pin with subtle soft glow)
              markers.add(
                Marker(
                  markerId: const MarkerId('child_current'),
                  position: LatLng(location.latitude, location.longitude),
                  icon: _childPinMarkerIcon ?? BitmapDescriptor.defaultMarker,
                  anchor: MarkerHelper.pinAnchor, // Pin tip anchored precisely to coordinates
                  infoWindow: const InfoWindow(title: "Child's current location"),
                ),
              );

              // If previous location exists, show previous marker, polyline, and directional arrow
              if (_previousLocation != null) {
                markers.add(
                  Marker(
                    markerId: const MarkerId('child_previous'),
                    position: LatLng(_previousLocation!.latitude, _previousLocation!.longitude),
                    icon: _darkBlueMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    anchor: const Offset(0.5, 0.5),
                    infoWindow: const InfoWindow(title: "Child's previous location"),
                  ),
                );

                // Directional indicator / arrow along the trail pointing from previous to current
                final double midLat = (_previousLocation!.latitude + location.latitude) / 2.0;
                final double midLng = (_previousLocation!.longitude + location.longitude) / 2.0;
                final double bearing = _calculateBearing(
                  _previousLocation!.latitude,
                  _previousLocation!.longitude,
                  location.latitude,
                  location.longitude,
                );

                markers.add(
                  Marker(
                    markerId: const MarkerId('trail_arrow'),
                    position: LatLng(midLat, midLng),
                    icon: _arrowIcon ?? BitmapDescriptor.defaultMarker,
                    rotation: bearing,
                    anchor: const Offset(0.5, 0.5),
                    flat: true,
                  ),
                );

                polylines.add(
                  Polyline(
                    polylineId: const PolylineId('recent_movement_trail'),
                    points: [
                      LatLng(_previousLocation!.latitude, _previousLocation!.longitude),
                      LatLng(location.latitude, location.longitude),
                    ],
                    color: const Color(0xFF1E3A8A), // Dark blue trail
                    width: 3,
                  ),
                );
              }
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    // ---------------- MAP ----------------
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: AppDecorations.neumorphicCard(radius: 24),
                          child: location == null
                              ? const Center(child: Text('Waiting for child\'s location...'))
                              : GoogleMap(
                                  style: AppDecorations.darkNavyMapStyle,
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(location.latitude, location.longitude),
                                    zoom: 15,
                                  ),
                                  onMapCreated: (controller) => _mapController = controller,
                                  markers: markers,
                                  polylines: polylines,
                                  circles: circles,
                                ),
                        ),
                      ),
                    ),

                const SizedBox(height: 12),

                // ---------------- STATS ----------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<Map<String, dynamic>?>(
                          stream: _firestoreService.streamSafetyRequest(childUid),
                          builder: (context, safetySnap) {
                            final isPaused = safetySnap.data?['status'] == 'approved';
                            return StatTile(
                              icon: isPaused ? Icons.pause_circle_outline_rounded : Icons.access_time_rounded,
                              label: isPaused ? 'Location' : 'Last Updated',
                              value: isPaused
                                  ? 'Paused'
                                  : (location == null ? '--' : _formatTime(location.timestamp)),
                              iconColor: isPaused ? AppColors.accent : AppColors.primary,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
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

                const SizedBox(height: 12),

                // ---------------- RECENT ACTIVITIES ----------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StreamBuilder<Map<String, dynamic>?>(
                    stream: _firestoreService.streamSafetyRequest(childUid),
                    builder: (context, safetySnapshot) {
                      final safetyData = safetySnapshot.data;
                      final safetyStatus = safetyData?['status'] as String?;
                      final childName = (safetyData?['childName'] as String?)?.isNotEmpty == true
                          ? safetyData!['childName'] as String
                          : 'Child';

                      if (safetyStatus == 'pending') {
                        return CustomCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.pause_circle_filled_rounded, color: AppColors.primary, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '$childName wants to pause location sharing.',
                                      style: AppTextStyles.heading.copyWith(fontSize: 13),
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _firestoreService.rejectSafetyRequest(childUid),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Keep Tracking',
                                      style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _firestoreService.approveSafetyRequest(childUid),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text(
                                      'Approve',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      if (safetyStatus == 'approved') {
                        return CustomCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Location sharing is paused',
                                      style: AppTextStyles.heading.copyWith(fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$childName was marked safe by parent',
                                      style: AppTextStyles.subheading.copyWith(fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return StreamBuilder<List<SosAlert>>(
                        stream: _firestoreService.streamAlertHistory(childUid),
                        builder: (context, alertSnapshot) {
                          return StreamBuilder<List<GeofenceEvent>>(
                            stream: _firestoreService.streamGeofenceEvents(childUid),
                            builder: (context, geofenceSnapshot) {
                              final alerts = alertSnapshot.data ?? [];
                              final geofenceEvents = geofenceSnapshot.data ?? [];

                              final latestAlert = alerts.isNotEmpty ? alerts.first : null;
                              final latestGeofence = geofenceEvents.isNotEmpty ? geofenceEvents.first : null;

                              String activityTitle = 'Normal monitoring active';
                              String activitySubtitle = 'No emergency events detected';
                              IconData activityIcon = Icons.check_circle_outline_rounded;
                              Color activityColor = AppColors.success;

                              // Candidate timestamps from real Firestore streams
                              final DateTime? alertTime = latestAlert?.timestamp;
                              final DateTime? geofenceTime = latestGeofence?.timestamp;
                              final DateTime? locTime = location?.timestamp;

                              // Determine which event is truly the most recent
                              DateTime? newestTime;
                              String newestType = 'none';

                              if (alertTime != null) {
                                newestTime = alertTime;
                                newestType = 'alert';
                              }
                              if (geofenceTime != null && (newestTime == null || geofenceTime.isAfter(newestTime))) {
                                newestTime = geofenceTime;
                                newestType = 'geofence';
                              }
                              if (locTime != null && (newestTime == null || locTime.isAfter(newestTime))) {
                                newestTime = locTime;
                                newestType = 'location';
                              }

                              if (newestType == 'alert' && latestAlert != null) {
                                final isRecentActive = latestAlert.status == 'active';
                                final isAuto = latestAlert.source == 'automatic_sos';
                                if (isAuto) {
                                  activityTitle = isRecentActive ? 'Automatic SOS Triggered' : 'Automatic SOS Resolved';
                                } else {
                                  activityTitle = isRecentActive ? 'SOS Alert Triggered' : 'Past SOS Resolved';
                                }
                                activitySubtitle = '${_formatDate(latestAlert.timestamp)} at ${_formatTime(latestAlert.timestamp)} • Lat: ${latestAlert.latitude.toStringAsFixed(4)}, Lng: ${latestAlert.longitude.toStringAsFixed(4)}';
                                activityIcon = isRecentActive ? Icons.warning_rounded : Icons.history_rounded;
                                activityColor = isRecentActive ? AppColors.danger : AppColors.primary;
                              } else if (newestType == 'geofence' && latestGeofence != null) {
                                final isEnter = latestGeofence.eventType == 'ENTER';
                                final isUnexpected = latestGeofence.eventType == 'UNEXPECTED_EXIT';

                                if (isEnter) {
                                  activityTitle = 'Entered ${latestGeofence.safePlaceName}';
                                  activityIcon = Icons.login_rounded;
                                  activityColor = AppColors.success;
                                } else if (isUnexpected) {
                                  activityTitle = 'Unexpected Exit: ${latestGeofence.safePlaceName}';
                                  activityIcon = Icons.warning_amber_rounded;
                                  activityColor = AppColors.danger;
                                } else {
                                  activityTitle = 'Left ${latestGeofence.safePlaceName}';
                                  activityIcon = Icons.logout_rounded;
                                  activityColor = AppColors.primaryDark;
                                }
                                activitySubtitle = '${_formatTime(latestGeofence.timestamp)} • ${_formatTimeAgo(latestGeofence.timestamp)}';
                              } else if (location != null) {
                                activityTitle = 'Live Location Updated';
                                if (_previousLocation != null) {
                                  final double distM = Geolocator.distanceBetween(
                                    _previousLocation!.latitude,
                                    _previousLocation!.longitude,
                                    location.latitude,
                                    location.longitude,
                                  );
                                  final distText = distM >= 1000
                                      ? '${(distM / 1000).toStringAsFixed(1)} km'
                                      : '${distM.round()} m';
                                  activitySubtitle = 'Moved $distText • ${_formatTimeAgo(location.timestamp)}';
                                } else {
                                  activitySubtitle = '${_formatDate(location.timestamp)} at ${_formatTime(location.timestamp)} • Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';
                                }
                                activityIcon = Icons.my_location_rounded;
                                activityColor = AppColors.primary;
                              }

                          return CustomCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(activityIcon, color: activityColor, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Recent Activity: ',
                                            style: AppTextStyles.subheading.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                          Expanded(
                                            child: Text(
                                              activityTitle,
                                              style: AppTextStyles.heading.copyWith(fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        activitySubtitle,
                                        style: AppTextStyles.subheading.copyWith(fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        );
      },
    );
      },
    );
  }

  // History tab: past SOS/safety events and Smart Geofence events from real Firestore data.
  Widget _buildHistoryScreen(String childUid) {
    return StreamBuilder<List<SosAlert>>(
      stream: _firestoreService.streamAlertHistory(childUid),
      builder: (context, alertSnapshot) {
        return StreamBuilder<List<GeofenceEvent>>(
          stream: _firestoreService.streamGeofenceEvents(childUid),
          builder: (context, geofenceSnapshot) {
            if (alertSnapshot.connectionState == ConnectionState.waiting &&
                geofenceSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final alerts = alertSnapshot.data ?? [];
            final geofences = geofenceSnapshot.data ?? [];

            // Merge events into a unified timeline
            final List<dynamic> combinedHistory = [...alerts, ...geofences];
            combinedHistory.sort((a, b) {
              final DateTime timeA = a is SosAlert ? a.timestamp : (a as GeofenceEvent).timestamp;
              final DateTime timeB = b is SosAlert ? b.timestamp : (b as GeofenceEvent).timestamp;
              return timeB.compareTo(timeA); // Newest first
            });

            if (combinedHistory.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: CustomCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_rounded, size: 40, color: AppColors.success),
                        const SizedBox(height: 16),
                        Text('No Safety Events', style: AppTextStyles.heading.copyWith(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          'No SOS alerts or geofence boundary events recorded yet.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: combinedHistory.length,
              itemBuilder: (context, index) {
                final item = combinedHistory[index];

                if (item is SosAlert) {
                  final isActive = item.status == 'active';
                  final isAuto = item.source == 'automatic_sos';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CustomCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.warning_rounded : Icons.check_circle_rounded,
                            color: isActive ? AppColors.danger : AppColors.success,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isAuto
                                            ? (isActive ? 'Automatic SOS Alert' : 'Resolved Auto SOS')
                                            : (isActive ? 'SOS Emergency Alert' : 'Resolved Alert'),
                                        style: AppTextStyles.heading.copyWith(fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isAuto) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'AUTO',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isActive ? AppColors.danger : AppColors.success).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isActive ? 'ACTIVE' : 'RESOLVED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isActive ? AppColors.danger : AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Time: ${_formatDate(item.timestamp)} at ${_formatTime(item.timestamp)}',
                                  style: AppTextStyles.subheading.copyWith(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'GPS: ${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}',
                                  style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.textLight),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  final ge = item as GeofenceEvent;
                  final isEnter = ge.eventType == 'ENTER';
                  final isUnexpected = ge.eventType == 'UNEXPECTED_EXIT';

                  final Color eventColor = isEnter
                      ? AppColors.success
                      : (isUnexpected ? AppColors.danger : AppColors.primaryDark);

                  final IconData eventIcon = isEnter
                      ? Icons.login_rounded
                      : (isUnexpected ? Icons.warning_amber_rounded : Icons.logout_rounded);

                  final String eventBadge = isEnter
                      ? 'ENTERED'
                      : (isUnexpected ? 'UNEXPECTED EXIT' : 'LEFT');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CustomCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(eventIcon, color: eventColor, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${isEnter ? "Entered" : (isUnexpected ? "Unexpected Exit from" : "Left")} ${ge.safePlaceName}',
                                        style: AppTextStyles.heading.copyWith(fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: eventColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        eventBadge,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: eventColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Time: ${_formatDate(ge.timestamp)} at ${_formatTime(ge.timestamp)} • ${_formatTimeAgo(ge.timestamp)}',
                                  style: AppTextStyles.subheading.copyWith(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Distance: ${ge.distance.round()} m from center • GPS Accuracy: ±${ge.accuracy.round()}m',
                                  style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.textLight),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  // Profile tab
  Widget _buildProfileScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          CustomCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_rounded, size: 44, color: AppColors.primaryDark),
                const SizedBox(height: 12),
                Text(widget.user.name, style: AppTextStyles.heading.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text(widget.user.email, style: AppTextStyles.subheading.copyWith(fontSize: 13)),
                const SizedBox(height: 12),
                Text(
                  'Role: Parent\nLink Code: ${widget.user.linkCode ?? "None"}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Profile -> Safe Places Navigation Tile
          CustomCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SafePlacesScreen(user: widget.user),
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: AppColors.primaryDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Safe Places',
                        style: AppTextStyles.heading.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage geofenced zones (Home, School, Office)',
                        style: AppTextStyles.subheading.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime time) {
    final d = time.day.toString().padLeft(2, '0');
    final m = time.month.toString().padLeft(2, '0');
    final y = time.year.toString();
    return '$d/$m/$y';
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
