// ============================================================
// geofence_event_model.dart
// ------------------------------------------------------------
// Represents a confirmed ENTER or EXIT event relative to a
// SafePlace. Stored in the Firestore "geofence_events" collection.
// Integrates cleanly with safety history and notifications.
// ============================================================

class GeofenceEvent {
  final String id;
  final String monitoredUid;
  final String safePlaceId;
  final String safePlaceName;
  final String eventType; // "ENTER" | "EXIT" | "UNEXPECTED_EXIT"
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double distance; // Distance in meters from the safe place center
  final bool isScheduled; // True if event took place during scheduled active window

  GeofenceEvent({
    required this.id,
    required this.monitoredUid,
    required this.safePlaceId,
    required this.safePlaceName,
    required this.eventType,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.distance,
    this.isScheduled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monitoredUid': monitoredUid,
      'safePlaceId': safePlaceId,
      'safePlaceName': safePlaceName,
      'eventType': eventType,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'distance': distance,
      'isScheduled': isScheduled,
    };
  }

  factory GeofenceEvent.fromMap(Map<String, dynamic> map, {String? docId}) {
    return GeofenceEvent(
      id: docId ?? map['id'] ?? '',
      monitoredUid: map['monitoredUid'] ?? '',
      safePlaceId: map['safePlaceId'] ?? '',
      safePlaceName: map['safePlaceName'] ?? 'Safe Place',
      eventType: map['eventType'] ?? 'ENTER',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      accuracy: (map['accuracy'] ?? 0.0).toDouble(),
      distance: (map['distance'] ?? 0.0).toDouble(),
      isScheduled: map['isScheduled'] ?? true,
    );
  }
}
