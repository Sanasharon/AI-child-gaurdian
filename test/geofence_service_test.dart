import 'package:flutter_test/flutter_test.dart';
import 'package:ai_child_guardian/models/safe_place_model.dart';
import 'package:ai_child_guardian/services/geofence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeofenceService Tests', () {
    late GeofenceService geofenceService;
    late SafePlace homePlace;

    setUp(() {
      geofenceService = GeofenceService(
        maxAcceptableAccuracyMeters: 50.0,
        hysteresisBufferMeters: 15.0,
        confirmationRequiredHits: 2,
        maxIntervalBetweenConfirmationHits: const Duration(minutes: 5),
      );

      homePlace = SafePlace(
        id: 'place_home',
        guardianUid: 'guardian_1',
        monitoredUid: 'child_1',
        name: 'Home',
        placeType: 'Home',
        latitude: 37.4220,
        longitude: -122.0841,
        radius: 100.0,
        isActive: true,
        alwaysActive: true,
      );
    });

    test('Initial reading sets baseline state without generating false alarms', () {
      final now = DateTime.now();

      // Child starts at Home center (inside)
      final event = geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: 37.4220,
        longitude: -122.0841,
        accuracy: 10.0,
        timestamp: now,
      );

      expect(event, isNull);
      final tracker = geofenceService.getTracker(homePlace.id);
      expect(tracker.currentState, GeofenceState.inside);
    });

    test('Rejects GPS readings when accuracy is worse than threshold', () {
      final now = DateTime.now();

      // Reading with 80m accuracy (threshold is 50m)
      final event = geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: 37.5000,
        longitude: -122.0841,
        accuracy: 80.0,
        timestamp: now,
      );

      expect(event, isNull);
      // State should remain uninitialized/unknown
      final tracker = geofenceService.getTracker(homePlace.id);
      expect(tracker.currentState, GeofenceState.unknown);
    });

    test('Confirms EXIT with 2-hit confirmation outside hysteresis buffer', () {
      final t0 = DateTime(2026, 9, 9, 10, 0, 0);

      // 1. Initial reading: inside Home
      geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: 37.4220,
        longitude: -122.0841,
        accuracy: 10.0,
        timestamp: t0,
      );

      // Coordinates ~500 meters away (definitely outside 100m + 15m buffer)
      final farLat = 37.4265;
      final farLng = -122.0841;

      // 2. Hit 1 outside: candidate recorded, event not yet confirmed
      final t1 = t0.add(const Duration(seconds: 10));
      final event1 = geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: farLat,
        longitude: farLng,
        accuracy: 12.0,
        timestamp: t1,
      );
      expect(event1, isNull);

      // 3. Hit 2 outside: confirmed EXIT event
      final t2 = t1.add(const Duration(seconds: 10));
      final event2 = geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: farLat,
        longitude: farLng,
        accuracy: 11.0,
        timestamp: t2,
      );

      expect(event2, isNotNull);
      expect(event2!.eventType, 'EXIT');
      expect(event2.safePlaceName, 'Home');
      expect(event2.safePlaceId, 'place_home');
    });

    test('Confirms ENTER when moving from outside to inside with 2 consecutive hits', () {
      final t0 = DateTime(2026, 9, 9, 10, 0, 0);

      // 1. Initial reading: starts outside
      final farLat = 37.4265;
      final farLng = -122.0841;
      geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: farLat,
        longitude: farLng,
        accuracy: 10.0,
        timestamp: t0,
      );

      // 2. Moves inside: Hit 1 inside
      final t1 = t0.add(const Duration(seconds: 10));
      final event1 = geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: 37.4220,
        longitude: -122.0841,
        accuracy: 8.0,
        timestamp: t1,
      );
      expect(event1, isNull);

      // 3. Hit 2 inside: confirmed ENTER
      final t2 = t1.add(const Duration(seconds: 10));
      final event2 = geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: 37.4220,
        longitude: -122.0841,
        accuracy: 9.0,
        timestamp: t2,
      );

      expect(event2, isNotNull);
      expect(event2!.eventType, 'ENTER');
      expect(event2.safePlaceName, 'Home');
    });

    test('Hysteresis prevents boundary fluctuation from triggering repeated events', () {
      final t0 = DateTime(2026, 9, 9, 10, 0, 0);

      // Initial reading: inside Home
      geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: 37.4220,
        longitude: -122.0841,
        accuracy: 10.0,
        timestamp: t0,
      );

      // Radius is 100m, buffer is 15m. Distance at ~105m is within the 100m + 15m hysteresis zone.
      // Lat offset ~0.00095 gives ~105 meters.
      final boundaryLat = 37.4220 + 0.00095;
      final t1 = t0.add(const Duration(seconds: 10));
      final event = geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: boundaryLat,
        longitude: -122.0841,
        accuracy: 10.0,
        timestamp: t1,
      );

      // Should not flip state or trigger EXIT
      expect(event, isNull);
      final tracker = geofenceService.getTracker(homePlace.id);
      expect(tracker.currentState, GeofenceState.inside);
    });

    test('Stale readings do not count as consecutive confirmation hits', () {
      final t0 = DateTime(2026, 9, 9, 10, 0, 0);

      // Baseline inside
      geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: 37.4220,
        longitude: -122.0841,
        accuracy: 10.0,
        timestamp: t0,
      );

      // Reading 1 outside
      final t1 = t0.add(const Duration(seconds: 10));
      geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: 37.4265,
        longitude: -122.0841,
        accuracy: 10.0,
        timestamp: t1,
      );

      // Reading 2 outside, but arrived 15 minutes later (> 5 min timeout)
      final t2 = t1.add(const Duration(minutes: 15));
      final event = geofenceService.evaluateLocation(
        monitoredUid: 'child_1',
        place: homePlace,
        latitude: 37.4265,
        longitude: -122.0841,
        accuracy: 10.0,
        timestamp: t2,
      );

      // Stale reading resets candidate count to 1, should not trigger confirmed event
      expect(event, isNull);
      final tracker = geofenceService.getTracker(homePlace.id);
      expect(tracker.candidateHits, 1);
    });

    test('Schedule evaluation correctly checks active hours and days', () {
      final scheduledPlace = SafePlace(
        id: 'place_work',
        guardianUid: 'guardian_1',
        name: 'Work',
        latitude: 37.4220,
        longitude: -122.0841,
        radius: 100.0,
        alwaysActive: false,
        activeDays: [1, 2, 3, 4, 5], // Monday - Friday
        startTime: '09:00',
        endTime: '17:00',
      );

      // Wednesday 14:00 (inside schedule)
      final wednesdayWorkHours = DateTime(2026, 9, 9, 14, 0);
      expect(GeofenceService.isScheduleActive(scheduledPlace, wednesdayWorkHours), isTrue);

      // Wednesday 20:00 (outside schedule hours)
      final wednesdayEvening = DateTime(2026, 9, 9, 20, 0);
      expect(GeofenceService.isScheduleActive(scheduledPlace, wednesdayEvening), isFalse);

      // Sunday 12:00 (outside schedule days)
      final sundayNoon = DateTime(2026, 9, 13, 12, 0);
      expect(GeofenceService.isScheduleActive(scheduledPlace, sundayNoon), isFalse);
    });
  });
}
