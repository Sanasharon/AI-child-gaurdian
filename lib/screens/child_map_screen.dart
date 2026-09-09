// ============================================================
// child_map_screen.dart
// ------------------------------------------------------------
// Dedicated Map page for the Child device.
// Features:
//   - Reuses Google Maps with AppDecorations.darkNavyMapStyle
//   - Shows child's live GPS location using MarkerHelper.createMinimalWhitePinMarker()
//   - Listens to active Safe Zones from Firestore (read-only)
//   - Follows the existing app theme and UI design
//   - No edit/create/delete controls for Safe Zones
//   - Safely manages GoogleMapController lifecycle
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/safe_place_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/marker_helper.dart';

class ChildMapScreen extends StatefulWidget {
  final AppUser user;
  const ChildMapScreen({super.key, required this.user});

  @override
  State<ChildMapScreen> createState() => _ChildMapScreenState();
}

class _ChildMapScreenState extends State<ChildMapScreen> {
  final _firestoreService = FirestoreService();
  GoogleMapController? _mapController;
  BitmapDescriptor? _childPinMarkerIcon;

  @override
  void initState() {
    super.initState();
    _initMarker();
  }

  Future<void> _initMarker() async {
    final icon = await MarkerHelper.createMinimalWhitePinMarker();
    if (mounted) {
      setState(() => _childPinMarkerIcon = icon);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If the child is linked to a parent, stream that guardian's active Safe Places.
    // Otherwise fallback to an empty stream.
    final parentUid = widget.user.linkedUid;

    return StreamBuilder<List<SafePlace>>(
      stream: parentUid != null && parentUid.isNotEmpty
          ? _firestoreService.streamActiveSafePlaces(
              guardianUid: parentUid,
              monitoredUid: widget.user.uid,
            )
          : Stream.value([]),
      builder: (context, safePlacesSnapshot) {
        final safePlaces = safePlacesSnapshot.data ?? [];

        return StreamBuilder<LocationModel?>(
          stream: _firestoreService.streamChildLocation(widget.user.uid),
          builder: (context, locationSnapshot) {
            final location = locationSnapshot.data;

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
            final circles = <Circle>{};

            // Display Safe Zones as read-only circles
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

            // Current child location marker (minimal white pin with subtle soft glow)
            if (location != null) {
              markers.add(
                Marker(
                  markerId: const MarkerId('child_current_location'),
                  position: LatLng(location.latitude, location.longitude),
                  icon: _childPinMarkerIcon ?? BitmapDescriptor.defaultMarker,
                  anchor: MarkerHelper.pinAnchor,
                  infoWindow: const InfoWindow(title: 'Your Location'),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: AppDecorations.neumorphicCard(radius: 24),
                child: location == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 12),
                            Text('Locating your device...'),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          GoogleMap(
                            style: AppDecorations.darkNavyMapStyle,
                            initialCameraPosition: CameraPosition(
                              target: LatLng(location.latitude, location.longitude),
                              zoom: 15,
                            ),
                            onMapCreated: (controller) => _mapController = controller,
                            markers: markers,
                            circles: circles,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                          ),

                          // Top indicator chip
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xE60F172A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Live Location',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Recenter button
                          Positioned(
                            bottom: 14,
                            right: 14,
                            child: FloatingActionButton.small(
                              heroTag: 'child_recenter_fab',
                              backgroundColor: const Color(0xFF1E1B4B),
                              elevation: 4,
                              onPressed: () {
                                if (_mapController != null) {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLng(
                                      LatLng(location.latitude, location.longitude),
                                    ),
                                  );
                                }
                              },
                              child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
