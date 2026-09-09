// ============================================================
// safe_place_model.dart
// ------------------------------------------------------------
// Represents a geofenced safe place defined by a guardian.
// Stored in the Firestore "safe_places" collection.
// Generic for any monitored entity / device.
// ============================================================

class SafePlace {
  final String id;
  final String guardianUid;
  final String? monitoredUid; // Optional target entity UID or null for all linked
  final String name;
  final String placeType; // "Home", "Office", "School", "Hospital", "Gym", "Custom"
  final double latitude;
  final double longitude;
  final double radius; // Radius in meters (e.g. 50m to 1000m)
  final bool isActive;
  final bool alwaysActive;
  final List<int> activeDays; // 1 = Monday ... 7 = Sunday (matching DateTime.weekday)
  final String? startTime; // "HH:mm" (24-hr format)
  final String? endTime; // "HH:mm" (24-hr format)
  final DateTime createdAt;

  SafePlace({
    required this.id,
    required this.guardianUid,
    this.monitoredUid,
    required this.name,
    this.placeType = 'Home',
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isActive = true,
    this.alwaysActive = true,
    this.activeDays = const [1, 2, 3, 4, 5, 6, 7],
    this.startTime,
    this.endTime,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guardianUid': guardianUid,
      'monitoredUid': monitoredUid,
      'name': name,
      'placeType': placeType,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isActive': isActive,
      'alwaysActive': alwaysActive,
      'activeDays': activeDays,
      'startTime': startTime,
      'endTime': endTime,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SafePlace.fromMap(Map<String, dynamic> map, {String? docId}) {
    return SafePlace(
      id: docId ?? map['id'] ?? '',
      guardianUid: map['guardianUid'] ?? '',
      monitoredUid: map['monitoredUid'],
      name: map['name'] ?? 'Safe Place',
      placeType: map['placeType'] ?? 'Home',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      radius: (map['radius'] ?? 100.0).toDouble(),
      isActive: map['isActive'] ?? true,
      alwaysActive: map['alwaysActive'] ?? true,
      activeDays: (map['activeDays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
      startTime: map['startTime'],
      endTime: map['endTime'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  SafePlace copyWith({
    String? id,
    String? guardianUid,
    String? monitoredUid,
    String? name,
    String? placeType,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isActive,
    bool? alwaysActive,
    List<int>? activeDays,
    String? startTime,
    String? endTime,
    DateTime? createdAt,
  }) {
    return SafePlace(
      id: id ?? this.id,
      guardianUid: guardianUid ?? this.guardianUid,
      monitoredUid: monitoredUid ?? this.monitoredUid,
      name: name ?? this.name,
      placeType: placeType ?? this.placeType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      isActive: isActive ?? this.isActive,
      alwaysActive: alwaysActive ?? this.alwaysActive,
      activeDays: activeDays ?? this.activeDays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
