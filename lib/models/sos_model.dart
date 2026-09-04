// ============================================================
// sos_model.dart
// ------------------------------------------------------------
// Represents a single emergency alert stored in the Firestore
// "sos_alerts" collection. Created when the child taps the
// SOS button in Child Mode.
// ============================================================

class SosAlert {
  final String childUid;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String status; // "active" or "resolved"

  SosAlert({
    required this.childUid,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'childUid': childUid,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  factory SosAlert.fromMap(Map<String, dynamic> map) {
    return SosAlert(
      childUid: map['childUid'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      status: map['status'] ?? 'active',
    );
  }
}
