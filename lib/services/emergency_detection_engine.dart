import 'dart:math' as math;

/// State of emergency detection pipeline
enum EmergencyDetectionState {
  monitoring,
  impactDetected,
  evaluatingInactivity,
  emergencyConfirmed,
}

/// Configuration thresholds for the detection engine
class EmergencyDetectionConfig {
  /// Acceleration magnitude threshold representing a strong impact (in m/s^2).
  /// Normal Earth gravity is ~9.8 m/s^2 (~1g). A hard fall/collision typically spikes > 25-30 m/s^2.
  final double impactThreshold;

  /// Gyroscope angular velocity threshold (in rad/s).
  /// Significant rotation during fall typically exceeds 3.5 - 4.0 rad/s.
  final double rotationThreshold;

  /// Maximum standard deviation/variance allowed during inactivity post-impact.
  final double inactivityVarianceThreshold;

  /// Time window required to confirm inactivity after impact (e.g. 1.5 - 3.0 seconds).
  final Duration inactivityDuration;

  /// Maximum window after impact where inactivity evaluation is valid.
  final Duration evaluationTimeout;

  const EmergencyDetectionConfig({
    this.impactThreshold = 26.0,
    this.rotationThreshold = 3.2,
    this.inactivityVarianceThreshold = 3.0,
    this.inactivityDuration = const Duration(milliseconds: 1500),
    this.evaluationTimeout = const Duration(milliseconds: 4000),
  });
}

/// A lightweight, decoupled sensor evaluation engine for emergency / fall detection.
/// 
/// Multi-signal detection logic:
/// 1. Evaluates sudden impact / acceleration spike (> [impactThreshold]).
/// 2. Considers recent rotational spike (> [rotationThreshold]) from gyroscope if available.
/// 3. Evaluates lack of movement (inactivity) for [inactivityDuration] post-impact.
/// 4. Does NOT trigger on a single sensor spike alone.
class EmergencyDetectionEngine {
  final EmergencyDetectionConfig config;

  EmergencyDetectionState _state = EmergencyDetectionState.monitoring;
  EmergencyDetectionState get state => _state;

  DateTime? _impactTimestamp;
  bool _abnormalRotationObserved = false;
  DateTime? _lastGyroTimestamp;

  // Buffer of acceleration magnitudes during post-impact evaluation window
  final List<_TimestampedValue> _postImpactAccels = [];

  // Callback when emergency is confirmed
  void Function()? onEmergencyDetected;

  // Callback on state changes (for UI or debugging)
  void Function(EmergencyDetectionState newState)? onStateChanged;

  EmergencyDetectionEngine({
    this.config = const EmergencyDetectionConfig(),
    this.onEmergencyDetected,
    this.onStateChanged,
  });

  /// Feeds a 3-axis accelerometer reading into the engine.
  /// [x], [y], [z] in m/s^2.
  void feedAccelerometer({
    required double x,
    required double y,
    required double z,
    required DateTime timestamp,
  }) {
    final double magnitude = math.sqrt(x * x + y * y + z * z);

    switch (_state) {
      case EmergencyDetectionState.monitoring:
        if (magnitude >= config.impactThreshold) {
          _impactTimestamp = timestamp;
          _state = EmergencyDetectionState.impactDetected;
          _postImpactAccels.clear();
          _postImpactAccels.add(_TimestampedValue(timestamp, magnitude));
          _notifyStateChange();
        }
        break;

      case EmergencyDetectionState.impactDetected:
      case EmergencyDetectionState.evaluatingInactivity:
        final elapsed = timestamp.difference(_impactTimestamp!);

        // If timeout exceeded without meeting emergency conditions, return to monitoring
        if (elapsed > config.evaluationTimeout) {
          reset();
          return;
        }

        _postImpactAccels.add(_TimestampedValue(timestamp, magnitude));

        // Once at least 500ms has elapsed since impact, begin evaluating inactivity window
        if (elapsed >= const Duration(milliseconds: 500)) {
          if (_state != EmergencyDetectionState.evaluatingInactivity) {
            _state = EmergencyDetectionState.evaluatingInactivity;
            _notifyStateChange();
          }

          _checkInactivity(timestamp);
        }
        break;

      case EmergencyDetectionState.emergencyConfirmed:
        // Already triggered, ignore further inputs until reset
        break;
    }
  }

  /// Feeds a 3-axis gyroscope reading into the engine.
  /// [x], [y], [z] in rad/s.
  void feedGyroscope({
    required double x,
    required double y,
    required double z,
    required DateTime timestamp,
  }) {
    final double rotationRate = math.sqrt(x * x + y * y + z * z);
    _lastGyroTimestamp = timestamp;

    if (rotationRate >= config.rotationThreshold) {
      _abnormalRotationObserved = true;
    }
  }

  void _checkInactivity(DateTime currentTimestamp) {
    if (_impactTimestamp == null) return;

    // Filter samples within the inactivity observation window
    // (excluding the immediate impact shock wave ~ first 400ms)
    final evaluationSamples = _postImpactAccels.where((sample) {
      final diff = sample.timestamp.difference(_impactTimestamp!);
      return diff >= const Duration(milliseconds: 400);
    }).toList();

    if (evaluationSamples.isEmpty) return;

    final windowDuration = currentTimestamp.difference(evaluationSamples.first.timestamp);
    if (windowDuration < config.inactivityDuration) {
      // Inactivity window not long enough yet
      return;
    }

    // Calculate variance of acceleration magnitude in the inactivity window
    double sum = 0;
    for (final s in evaluationSamples) {
      sum += s.value;
    }
    final mean = sum / evaluationSamples.length;

    double varianceSum = 0;
    for (final s in evaluationSamples) {
      varianceSum += (s.value - mean) * (s.value - mean);
    }
    final variance = varianceSum / evaluationSamples.length;
    final stdDev = math.sqrt(variance);

    // If device continues active heavy movement (e.g. child was running and jumped),
    // stdDev will remain high -> not an incapacitated emergency
    if (stdDev <= config.inactivityVarianceThreshold) {
      // Impact occurred, followed by inactivity.
      // Gyroscope check: if gyro is available and was recently updated, confirm abnormal rotation occurred.
      // If gyroscope was not available, impact + inactivity is sufficient.
      final bool gyroIsAvailable = _lastGyroTimestamp != null &&
          currentTimestamp.difference(_lastGyroTimestamp!).inSeconds < 10;

      if (!gyroIsAvailable || _abnormalRotationObserved) {
        _state = EmergencyDetectionState.emergencyConfirmed;
        _notifyStateChange();
        onEmergencyDetected?.call();
      } else {
        // Gyroscope was present but no abnormal rotation detected (e.g. phone set down firmly on table)
        reset();
      }
    }
  }

  void _notifyStateChange() {
    onStateChanged?.call(_state);
  }

  /// Resets engine back to monitoring state
  void reset() {
    _state = EmergencyDetectionState.monitoring;
    _impactTimestamp = null;
    _abnormalRotationObserved = false;
    _postImpactAccels.clear();
    _notifyStateChange();
  }
}

class _TimestampedValue {
  final DateTime timestamp;
  final double value;
  const _TimestampedValue(this.timestamp, this.value);
}
