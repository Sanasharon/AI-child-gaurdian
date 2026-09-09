// ============================================================
// location_service.dart
// ------------------------------------------------------------
// Handles everything related to GPS:
//   1. Requesting location permission from the user.
//   2. Reading the device's current position.
//   3. Starting a repeating 10-second timer that pushes the
//      child's position to Firestore automatically.
// ============================================================

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'firestore_service.dart';
import '../models/location_model.dart';

class LocationService {
  final FirestoreService _firestoreService = FirestoreService();
  Timer? _trackingTimer;

  // --------------------------------------------------------
  // Ask the user for location permission. Must be called
  // before trying to read GPS coordinates.
  // --------------------------------------------------------
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services (GPS) are off at the OS level.
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // User must enable it manually from app settings.
      return false;
    }

    return true;
  }

  // --------------------------------------------------------
  // Get a single current GPS reading (latitude/longitude).
  // --------------------------------------------------------
  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // --------------------------------------------------------
  // Starts a repeating timer (every 10 seconds) that:
  //   1. Reads the current GPS position.
  //   2. Saves lat/lng/timestamp into Firestore under
  //      locations/{childUid}.
  // Call this once when Child Mode dashboard opens.
  // --------------------------------------------------------
  void startTracking(String childUid) {
    // Cancel any previous timer first (avoid duplicates).
    _trackingTimer?.cancel();

    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final position = await getCurrentPosition();
        final location = LocationModel(
          childUid: childUid,
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
          accuracy: position.accuracy,
        );
        await _firestoreService.updateLocation(location);
      } catch (e) {
        // In a production app we'd log this properly.
        // For Day 1 we just print it so it's visible during dev.
        print('Location update failed: $e');
      }
    });
  }

  // Call this when Child Mode dashboard closes / user logs out.
  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }
}
