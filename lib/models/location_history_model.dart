// ============================================================
// location_history_model.dart
// ------------------------------------------------------------
// Represents a single historical GPS data point stored in the
// Firestore "location_history" collection for future ML training.
// ============================================================

class LocationHistoryModel {
  final String childUid;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final int sequenceNumber;

  LocationHistoryModel({
    required this.childUid,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.sequenceNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'childUid': childUid,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'sequenceNumber': sequenceNumber,
    };
  }

  factory LocationHistoryModel.fromMap(Map<String, dynamic> map) {
    return LocationHistoryModel(
      childUid: map['childUid'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      accuracy: (map['accuracy'] ?? 10.0).toDouble(),
      sequenceNumber: (map['sequenceNumber'] ?? 0) as int,
    );
  }
}
