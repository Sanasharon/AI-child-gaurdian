// ============================================================
// geofence_service.dart
// ------------------------------------------------------------
// Rule-based Smart Geofencing Evaluation Engine.
// Responsibilities:
//   1. Geographic state determination:
//        UNKNOWN -> INSIDE
//        UNKNOWN -> OUTSIDE
//        OUTSIDE -> INSIDE = ENTER
//        INSIDE -> OUTSIDE = EXIT
//   2. Accept readings within accuracy threshold; reject noisy readings.
//   3. Hysteresis buffer to avoid boundary oscillation.
//   4. Multi-hit confirmation with time-window validation.
//   5. Independent state tracking per SafePlace.
//   6. Schedule evaluation logic (expected vs unexpected).
// ============================================================

import 'package:geolocator/geolocator.dart';
import '../models/safe_place_model.dart';
import '../models/geofence_event_model.dart';

enum GeofenceState {
  unknown,
  inside,
  outside,
}

class SafePlaceTracker {
  GeofenceState currentState = GeofenceState.unknown;
  GeofenceState candidateState = GeofenceState.unknown;
  int candidateHits = 0;
  DateTime? lastCandidateTimestamp;

  void reset() {
    currentState = GeofenceState.unknown;
    candidateState = GeofenceState.unknown;
    candidateHits = 0;
    lastCandidateTimestamp = null;
  }
}

class GeofenceService {
  // Configurable parameters
  final double maxAcceptableAccuracyMeters;
  final double hysteresisBufferMeters;
  final int confirmationRequiredHits;
  final Duration maxIntervalBetweenConfirmationHits;

  // Independent state tracker per Safe Place ID
  final Map<String, SafePlaceTracker> _trackers = {};

  GeofenceService({
    this.maxAcceptableAccuracyMeters = 65.0,
    this.hysteresisBufferMeters = 15.0,
    this.confirmationRequiredHits = 2,
    this.maxIntervalBetweenConfirmationHits = const Duration(minutes: 5),
  });

  SafePlaceTracker getTracker(String placeId) {
    return _trackers.putIfAbsent(placeId, () => SafePlaceTracker());
  }

  void resetTracker(String placeId) {
    _trackers.remove(placeId);
  }

  void clearAllTrackers() {
    _trackers.clear();
  }

  /// Checks if a SafePlace is currently active according to its schedule.
  static bool isScheduleActive(SafePlace place, DateTime now) {
    if (!place.isActive) return false;
    if (place.alwaysActive) return true;

    // Check active days (1 = Monday ... 7 = Sunday)
    if (!place.activeDays.contains(now.weekday)) {
      return false;
    }

    if (place.startTime == null || place.endTime == null) {
      return true;
    }

    try {
      final startParts = place.startTime!.split(':');
      final endParts = place.endTime!.split(':');
      if (startParts.length < 2 || endParts.length < 2) return true;

      final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final currentMinutes = now.hour * 60 + now.minute;

      if (startMinutes <= endMinutes) {
        return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
      } else {
        // Spans overnight (e.g. 22:00 to 06:00)
        return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
      }
    } catch (_) {
      return true;
    }
  }

  /// Evaluates a location update against a single SafePlace.
  /// Returns a [GeofenceEvent] if a confirmed state transition occurs, otherwise null.
  GeofenceEvent? evaluateLocation({
    required String monitoredUid,
    required SafePlace place,
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
  }) {
    // 1. Accuracy Check: reject readings worse than threshold
    if (accuracy > maxAcceptableAccuracyMeters) {
      return null;
    }

    // 2. Calculate distance between reading and SafePlace center
    final double distance = Geolocator.distanceBetween(
      place.latitude,
      place.longitude,
      latitude,
      longitude,
    );

    final tracker = getTracker(place.id);

    // 3. Raw state determination with hysteresis
    GeofenceState rawState;
    if (tracker.currentState == GeofenceState.inside) {
      // Must be distinctly outside the buffer zone to trigger outside
      if (distance > place.radius + hysteresisBufferMeters) {
        rawState = GeofenceState.outside;
      } else {
        rawState = GeofenceState.inside;
      }
    } else if (tracker.currentState == GeofenceState.outside) {
      // Must be distinctly inside the buffer zone to trigger inside
      if (distance <= place.radius - hysteresisBufferMeters) {
        rawState = GeofenceState.inside;
      } else {
        rawState = GeofenceState.outside;
      }
    } else {
      // Unknown state: neutral cutoff at boundary radius
      rawState = distance <= place.radius ? GeofenceState.inside : GeofenceState.outside;
    }

    // 4. Initial state setting (UNKNOWN -> INSIDE / OUTSIDE)
    if (tracker.currentState == GeofenceState.unknown) {
      tracker.currentState = rawState;
      tracker.candidateState = rawState;
      tracker.candidateHits = 1;
      tracker.lastCandidateTimestamp = timestamp;
      // UNKNOWN initialization does not generate false alarms
      return null;
    }

    // 5. If state matches current confirmed state, reset candidate
    if (rawState == tracker.currentState) {
      tracker.candidateState = rawState;
      tracker.candidateHits = 0;
      tracker.lastCandidateTimestamp = timestamp;
      return null;
    }

    // 6. Multi-hit confirmation with time-window validation
    if (tracker.candidateState == rawState) {
      final lastTime = tracker.lastCandidateTimestamp;
      if (lastTime != null) {
        final elapsed = timestamp.difference(lastTime).abs();
        if (elapsed > maxIntervalBetweenConfirmationHits) {
          // Stale reading: restart confirmation count
          tracker.candidateHits = 1;
          tracker.lastCandidateTimestamp = timestamp;
          return null;
        }
      }
      tracker.candidateHits++;
      tracker.lastCandidateTimestamp = timestamp;
    } else {
      tracker.candidateState = rawState;
      tracker.candidateHits = 1;
      tracker.lastCandidateTimestamp = timestamp;
      return null;
    }

    // 7. Check if required consecutive hits reached
    if (tracker.candidateHits >= confirmationRequiredHits) {
      final previousState = tracker.currentState;
      tracker.currentState = rawState;
      tracker.candidateHits = 0;

      final bool isScheduled = isScheduleActive(place, timestamp);

      // OUTSIDE -> INSIDE = ENTER
      if (previousState == GeofenceState.outside && rawState == GeofenceState.inside) {
        return GeofenceEvent(
          id: '${monitoredUid}_${place.id}_${timestamp.millisecondsSinceEpoch}',
          monitoredUid: monitoredUid,
          safePlaceId: place.id,
          safePlaceName: place.name,
          eventType: 'ENTER',
          timestamp: timestamp,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          distance: distance,
          isScheduled: isScheduled,
        );
      }

      // INSIDE -> OUTSIDE = EXIT
      if (previousState == GeofenceState.inside && rawState == GeofenceState.outside) {
        // Schedule determines if exit was unexpected
        final String eventType = (!place.alwaysActive && isScheduled) ? 'UNEXPECTED_EXIT' : 'EXIT';

        return GeofenceEvent(
          id: '${monitoredUid}_${place.id}_${timestamp.millisecondsSinceEpoch}',
          monitoredUid: monitoredUid,
          safePlaceId: place.id,
          safePlaceName: place.name,
          eventType: eventType,
          timestamp: timestamp,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          distance: distance,
          isScheduled: isScheduled,
        );
      }
    }

    return null;
  }
}
