import 'package:flutter_test/flutter_test.dart';
import 'package:ai_child_guardian/models/location_model.dart';
import 'package:ai_child_guardian/models/location_history_model.dart';
import 'package:ai_child_guardian/services/location_service.dart';

void main() {
  group('LocationModel Tests', () {
    test('Serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime(2026, 9, 11, 14, 30, 0);
      final model = LocationModel(
        childUid: 'child_xyz',
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        accuracy: 8.5,
      );

      final map = model.toMap();
      expect(map['childUid'], equals('child_xyz'));
      expect(map['latitude'], equals(37.7749));
      expect(map['longitude'], equals(-122.4194));
      expect(map['timestamp'], equals(now.toIso8601String()));
      expect(map['accuracy'], equals(8.5));

      final restored = LocationModel.fromMap(map);
      expect(restored.childUid, equals('child_xyz'));
      expect(restored.latitude, equals(37.7749));
      expect(restored.longitude, equals(-122.4194));
      expect(restored.timestamp, equals(now));
      expect(restored.accuracy, equals(8.5));
    });

    test('Handles missing accuracy with default value', () {
      final map = {
        'childUid': 'child_abc',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'timestamp': '2026-09-11T12:00:00.000',
      };

      final restored = LocationModel.fromMap(map);
      expect(restored.childUid, equals('child_abc'));
      expect(restored.latitude, equals(40.7128));
      expect(restored.longitude, equals(-74.0060));
      expect(restored.accuracy, equals(10.0));
    });
  });

  group('LocationPermissionState Enum Tests', () {
    test('Contains all expected states', () {
      expect(LocationPermissionState.values, contains(LocationPermissionState.granted));
      expect(LocationPermissionState.values, contains(LocationPermissionState.backgroundGranted));
      expect(LocationPermissionState.values, contains(LocationPermissionState.serviceDisabled));
      expect(LocationPermissionState.values, contains(LocationPermissionState.denied));
      expect(LocationPermissionState.values, contains(LocationPermissionState.deniedForever));
      expect(LocationPermissionState.values, contains(LocationPermissionState.backgroundDenied));
    });
  });

  group('LocationHistoryModel Tests', () {
    test('Serializes toMap and deserializes fromMap correctly with sequenceNumber', () {
      final now = DateTime(2026, 9, 11, 15, 0, 0);
      final history = LocationHistoryModel(
        childUid: 'child_ml_1',
        latitude: 37.422,
        longitude: -122.084,
        timestamp: now,
        accuracy: 5.0,
        sequenceNumber: 42,
      );

      final map = history.toMap();
      expect(map['childUid'], equals('child_ml_1'));
      expect(map['latitude'], equals(37.422));
      expect(map['longitude'], equals(-122.084));
      expect(map['timestamp'], equals(now.toIso8601String()));
      expect(map['accuracy'], equals(5.0));
      expect(map['sequenceNumber'], equals(42));

      final fromMapObj = LocationHistoryModel.fromMap(map);
      expect(fromMapObj.childUid, equals('child_ml_1'));
      expect(fromMapObj.latitude, equals(37.422));
      expect(fromMapObj.longitude, equals(-122.084));
      expect(fromMapObj.timestamp, equals(now));
      expect(fromMapObj.accuracy, equals(5.0));
      expect(fromMapObj.sequenceNumber, equals(42));
    });

    test('Handles default accuracy and sequenceNumber fallback', () {
      final map = {
        'childUid': 'child_ml_fallback',
        'latitude': 37.0,
        'longitude': -122.0,
        'timestamp': '2026-09-11T12:00:00.000',
      };

      final fromMapObj = LocationHistoryModel.fromMap(map);
      expect(fromMapObj.accuracy, equals(10.0));
      expect(fromMapObj.sequenceNumber, equals(0));
    });
  });
}
