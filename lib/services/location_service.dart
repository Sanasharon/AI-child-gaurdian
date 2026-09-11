// ============================================================
// location_service.dart
// ------------------------------------------------------------
// Handles everything related to GPS:
//   1. Requesting granular location permissions (when-in-use,
//      always/background, and checking location service toggle).
//   2. Reading the device's current position.
//   3. Background-capable position streaming via Geolocator
//      foreground service notification.
//   4. Throttling updates to ~10-second intervals to Firestore
//      locations/{childUid}.
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'firestore_service.dart';
import '../models/location_model.dart';
import '../models/location_history_model.dart';

/// Detailed result of location permission checks
enum LocationPermissionState {
  granted,
  backgroundGranted,
  serviceDisabled,
  denied,
  deniedForever,
  backgroundDenied,
}

class LocationService {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<Position>? _positionStreamSub;
  Timer? _fallbackTimer;
  DateTime? _lastUploadTime;
  String? _activeChildUid;
  bool _isTracking = false;
  int _sequenceNumber = 0;

  bool get isTracking => _isTracking;

  // --------------------------------------------------------
  // Check and request location permissions, including background
  // location ("Allow all the time") for uninterrupted tracking.
  // --------------------------------------------------------
  Future<LocationPermissionState> requestDetailedPermissions() async {
    // 1. Verify location services are enabled on the OS level
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionState.serviceDisabled;
    }

    // 2. Check and request foreground location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionState.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionState.deniedForever;
    }

    // 3. For Android 10+ (API 29+), check/request background permission if applicable
    if (defaultTargetPlatform == TargetPlatform.android) {
      final bgStatus = await ph.Permission.locationAlways.status;
      if (!bgStatus.isGranted) {
        final requestedBg = await ph.Permission.locationAlways.request();
        if (!requestedBg.isGranted) {
          // Foreground permission is still granted, but background might be restricted
          return LocationPermissionState.backgroundDenied;
        }
      }
      return LocationPermissionState.backgroundGranted;
    }

    return LocationPermissionState.granted;
  }

  // --------------------------------------------------------
  // Backward-compatible simple permission check.
  // Returns true if location can be read (at least foreground).
  // --------------------------------------------------------
  Future<bool> requestPermission() async {
    final status = await requestDetailedPermissions();
    return status == LocationPermissionState.granted ||
        status == LocationPermissionState.backgroundGranted ||
        status == LocationPermissionState.backgroundDenied;
  }

  // Helper to open OS location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  // Helper to open App settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  // --------------------------------------------------------
  // Get a single current GPS reading (latitude/longitude).
  // --------------------------------------------------------
  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  // --------------------------------------------------------
  // Starts background location tracking for childUid:
  //   1. Runs Geolocator position stream with Android foreground
  //      notification configuration so updates continue when
  //      app is minimized or screen is locked.
  //   2. Throttles updates to ~10-second intervals to minimize
  //      Firestore writes while maintaining real-time accuracy.
  //   3. Runs a safety fallback timer every 10s in case GPS
  //      stream is temporarily throttled by hardware.
  // --------------------------------------------------------
  void startTracking(String childUid) {
    if (_isTracking && _activeChildUid == childUid) return;

    stopTracking();

    _activeChildUid = childUid;
    _isTracking = true;

    // Immediately push initial position
    _pushCurrentLocation(childUid);

    // Configure platform-specific settings with foreground notification
    final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'AI Child Guardian Active',
          notificationText: 'Location tracking and emergency monitoring are active',
          notificationChannelName: 'Location Tracking',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    try {
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _handleNewPosition(childUid, position);
        },
        onError: (e) {
          debugPrint('Geolocator position stream error: $e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to start getPositionStream: $e');
    }

    // Safety fallback timer: ensures at least one update every 10s if positionStream is quiet
    _fallbackTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final now = DateTime.now();
      if (_lastUploadTime == null || now.difference(_lastUploadTime!).inSeconds >= 9) {
        await _pushCurrentLocation(childUid);
      }
    });
  }

  Future<void> _pushCurrentLocation(String childUid) async {
    try {
      final position = await getCurrentPosition();
      _handleNewPosition(childUid, position);
    } catch (e) {
      debugPrint('Push location error: $e');
    }
  }

  void _handleNewPosition(String childUid, Position position) {
    final now = DateTime.now();
    // Throttle to avoid writes faster than ~9 seconds
    if (_lastUploadTime != null && now.difference(_lastUploadTime!).inMilliseconds < 9000) {
      return;
    }

    _lastUploadTime = now;
    final currentSeq = ++_sequenceNumber;

    final location = LocationModel(
      childUid: childUid,
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: now,
      accuracy: position.accuracy,
    );

    // 1. Live location write to locations/{childUid} (Parent Dashboard depends on this)
    _firestoreService.updateLocation(location).catchError((e) {
      debugPrint('Location update failed: $e');
    });

    // 2. Historical GPS record write to location_history collection for ML training
    // Kept isolated so historical writes never break live tracking
    final historyRecord = LocationHistoryModel(
      childUid: childUid,
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: now,
      accuracy: position.accuracy,
      sequenceNumber: currentSeq,
    );

    _firestoreService.recordLocationHistory(historyRecord).catchError((e) {
      debugPrint('Location history recording failed: $e');
    });
  }

  // Call this when Child Mode dashboard closes / user logs out / Safety Pause approved.
  void stopTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _activeChildUid = null;
    _isTracking = false;
    _lastUploadTime = null;
  }
}

