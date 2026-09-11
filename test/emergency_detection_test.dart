import 'package:flutter_test/flutter_test.dart';
import 'package:ai_child_guardian/models/sos_model.dart';
import 'package:ai_child_guardian/services/emergency_detection_engine.dart';

void main() {
  group('SosAlert Model Tests', () {
    test('Defaults source to manual when omitted', () {
      final alert = SosAlert(
        childUid: 'child_123',
        latitude: 37.422,
        longitude: -122.084,
        timestamp: DateTime(2026, 9, 9, 12, 0),
      );

      expect(alert.source, equals('manual'));
      final map = alert.toMap();
      expect(map['source'], equals('manual'));
    });

    test('Supports automatic_sos source serialization and deserialization', () {
      final alert = SosAlert(
        childUid: 'child_123',
        latitude: 37.422,
        longitude: -122.084,
        timestamp: DateTime(2026, 9, 9, 12, 0),
        source: 'automatic_sos',
      );

      expect(alert.source, equals('automatic_sos'));
      final map = alert.toMap();
      expect(map['source'], equals('automatic_sos'));

      final fromMapAlert = SosAlert.fromMap(map);
      expect(fromMapAlert.source, equals('automatic_sos'));
      expect(fromMapAlert.childUid, equals('child_123'));
    });

    test('Backwards compatible with legacy maps lacking source', () {
      final legacyMap = {
        'childUid': 'child_legacy',
        'latitude': 37.4,
        'longitude': -122.0,
        'timestamp': '2026-09-09T10:00:00.000',
        'status': 'active',
      };

      final alert = SosAlert.fromMap(legacyMap);
      expect(alert.source, equals('manual'));
    });
  });

  group('EmergencyDetectionEngine Tests', () {
    late EmergencyDetectionEngine engine;
    bool emergencyCallbackCalled = false;

    setUp(() {
      emergencyCallbackCalled = false;
      engine = EmergencyDetectionEngine(
        config: const EmergencyDetectionConfig(
          impactThreshold: 26.0,
          rotationThreshold: 3.0,
          inactivityVarianceThreshold: 2.0,
          inactivityDuration: Duration(milliseconds: 1000),
          evaluationTimeout: Duration(milliseconds: 3000),
        ),
        onEmergencyDetected: () {
          emergencyCallbackCalled = true;
        },
      );
    });

    test('Normal walking/movement does NOT trigger emergency', () {
      final startTime = DateTime(2026, 9, 9, 10, 0, 0);

      // Normal movements around 9.8 m/s^2 ± 2 m/s^2
      for (int i = 0; i < 30; i++) {
        final time = startTime.add(Duration(milliseconds: i * 100));
        engine.feedAccelerometer(
          x: 1.0,
          y: 2.0,
          z: 9.8,
          timestamp: time,
        );
      }

      expect(engine.state, equals(EmergencyDetectionState.monitoring));
      expect(emergencyCallbackCalled, isFalse);
    });

    test('High impact spike alone followed by active movement does NOT trigger emergency', () {
      final startTime = DateTime(2026, 9, 9, 10, 0, 0);

      // Impact spike: magnitude ~ 30 m/s^2
      engine.feedAccelerometer(
        x: 15.0,
        y: 20.0,
        z: 18.0,
        timestamp: startTime,
      );

      expect(engine.state, equals(EmergencyDetectionState.impactDetected));

      // Post-impact heavy active movement (running/jumping) -> high variance
      for (int i = 1; i <= 20; i++) {
        final time = startTime.add(Duration(milliseconds: i * 100));
        final dynamicAccel = (i % 2 == 0) ? 5.0 : 20.0;
        engine.feedAccelerometer(
          x: dynamicAccel,
          y: 5.0,
          z: 9.8,
          timestamp: time,
        );
      }

      // Should not confirm emergency because variance is high
      expect(emergencyCallbackCalled, isFalse);
    });

    test('Multi-signal: High impact + abnormal rotation + inactivity triggers emergency', () {
      final startTime = DateTime(2026, 9, 9, 10, 0, 0);

      // 1. Gyroscope detects abnormal tumble/fall rotation
      engine.feedGyroscope(
        x: 3.5,
        y: 2.0,
        z: 1.0,
        timestamp: startTime,
      );

      // 2. High impact spike
      engine.feedAccelerometer(
        x: 18.0,
        y: 22.0,
        z: 15.0,
        timestamp: startTime,
      );
      expect(engine.state, equals(EmergencyDetectionState.impactDetected));

      // 3. Post-impact inactivity (device rests still on ground, accel ~ 9.8 m/s^2 with minimal variance)
      for (int i = 5; i <= 20; i++) {
        final time = startTime.add(Duration(milliseconds: i * 100));
        engine.feedAccelerometer(
          x: 0.1,
          y: 0.1,
          z: 9.8,
          timestamp: time,
        );
      }

      expect(engine.state, equals(EmergencyDetectionState.emergencyConfirmed));
      expect(emergencyCallbackCalled, isTrue);
    });

    test('Reset returns engine back to monitoring state', () {
      final startTime = DateTime(2026, 9, 9, 10, 0, 0);

      engine.feedAccelerometer(
        x: 20.0,
        y: 20.0,
        z: 10.0,
        timestamp: startTime,
      );
      expect(engine.state, equals(EmergencyDetectionState.impactDetected));

      engine.reset();
      expect(engine.state, equals(EmergencyDetectionState.monitoring));
    });
  });
}
