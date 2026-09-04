// ============================================================
// location_model.dart
// ------------------------------------------------------------
// Represents a single GPS location update, stored in the
// Firestore "locations" collection. Each child writes one of
// these every 10 seconds so the parent can see live movement.
// ============================================================

class LocationModel {
  final String childUid;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationModel({
    required this.childUid,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'childUid': childUid,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      childUid: map['childUid'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
