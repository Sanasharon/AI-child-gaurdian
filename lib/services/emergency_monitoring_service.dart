import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sos_model.dart';
import 'emergency_detection_engine.dart';
import 'firestore_service.dart';
import 'location_service.dart';

/// Service responsible for managing real-time sensor streams,
/// emergency confirmation countdown alerts, and triggering automatic SOS.
class EmergencyMonitoringService {
  static final EmergencyMonitoringService _instance = EmergencyMonitoringService._internal();
  factory EmergencyMonitoringService() => _instance;
  EmergencyMonitoringService._internal();

  final EmergencyDetectionEngine engine = EmergencyDetectionEngine();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();

  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  Timer? _countdownTimer;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  bool _isEmergencyActive = false;
  bool get isEmergencyActive => _isEmergencyActive;

  int _countdownSecondsRemaining = 10;
  int get countdownSecondsRemaining => _countdownSecondsRemaining;

  String? _activeChildUid;

  // Stream controller to broadcast countdown updates to active UI if needed
  final StreamController<int> _countdownStreamController = StreamController<int>.broadcast();
  Stream<int> get countdownStream => _countdownStreamController.stream;

  static const String notificationChannelId = 'emergency_confirmation_channel';
  static const String notificationChannelName = 'Emergency Confirmation';
  static const int emergencyNotificationId = 999;

  static const String actionImOkay = 'ACTION_IM_OKAY';
  static const String actionSendSos = 'ACTION_SEND_SOS';

  /// Initializes local notifications and setup callbacks.
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationActionReceived,
    );

    // Create high-priority notification channel
    const androidNotificationChannel = AndroidNotificationChannel(
      notificationChannelId,
      notificationChannelName,
      description: 'Urgent emergency confirmation alerts with interactive actions',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(androidNotificationChannel);

    // Wire engine callback
    engine.onEmergencyDetected = _handleEmergencyDetected;
  }

  /// Starts listening to sensor events for the given child UID.
  Future<void> startMonitoring(String childUid) async {
    if (_isMonitoring && _activeChildUid == childUid) return;

    _activeChildUid = childUid;
    _isMonitoring = true;
    engine.reset();

    // Subscribe to accelerometer stream (measures acceleration without gravity or with gravity)
    // userAccelerometerEventStream gives linear acceleration without gravity (spike detection)
    _accelSubscription?.cancel();
    _accelSubscription = userAccelerometerEventStream().listen((event) {
      // Linear acceleration spike: add baseline gravity vector magnitude (~9.8) for total impact calculation
      engine.feedAccelerometer(
        x: event.x,
        y: event.y,
        z: event.z + 9.8,
        timestamp: DateTime.now(),
      );
    }, onError: (e) {
      debugPrint('Error on userAccelerometerEventStream: $e');
    });

    // Subscribe to gyroscope stream if available
    _gyroSubscription?.cancel();
    _gyroSubscription = gyroscopeEventStream().listen((event) {
      engine.feedGyroscope(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );
    }, onError: (e) {
      debugPrint('Error on gyroscopeEventStream: $e');
    });
  }

  /// Stops sensor monitoring.
  void stopMonitoring() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _cancelEmergencyConfirmation();
    _isMonitoring = false;
    engine.reset();
  }

  void _handleEmergencyDetected() {
    if (_isEmergencyActive) return;
    _startEmergencyConfirmation();
  }

  /// Initiates the 10-second confirmation countdown and high-priority notification
  void _startEmergencyConfirmation() {
    _isEmergencyActive = true;
    _countdownSecondsRemaining = 10;
    _countdownStreamController.add(_countdownSecondsRemaining);

    _showOrUpdateNotification(_countdownSecondsRemaining);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSecondsRemaining--;
      _countdownStreamController.add(_countdownSecondsRemaining);

      if (_countdownSecondsRemaining <= 0) {
        timer.cancel();
        _triggerAutomaticSos();
      } else {
        _showOrUpdateNotification(_countdownSecondsRemaining);
      }
    });
  }

  /// Shows or updates high-priority emergency confirmation notification with action buttons
  Future<void> _showOrUpdateNotification(int secondsRemaining) async {
    final androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: 'Urgent emergency confirmation alerts with interactive actions',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      actions: const [
        AndroidNotificationAction(
          actionImOkay,
          "I'm Okay",
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionSendSos,
          'Send SOS',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: emergencyNotificationId,
      title: 'Are you okay? Possible Emergency Detected',
      body: 'Sending SOS to your parents in $secondsRemaining seconds...',
      notificationDetails: notificationDetails,
    );
  }

  /// Responds to notification action button clicks
  void _onNotificationActionReceived(NotificationResponse response) {
    if (response.actionId == actionImOkay) {
      cancelEmergency();
    } else if (response.actionId == actionSendSos) {
      immediateSos();
    }
  }

  /// Child pressed "I'm Okay": Cancel alert, reset engine, and resume normal monitoring
  void cancelEmergency() {
    _cancelEmergencyConfirmation();
    engine.reset();
  }

  /// Child pressed "Send SOS": Immediately triggers automatic SOS without waiting for countdown
  Future<void> immediateSos() async {
    _cancelEmergencyConfirmation();
    await _triggerAutomaticSos();
  }

  void _cancelEmergencyConfirmation() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isEmergencyActive = false;
    _notificationsPlugin.cancel(id: emergencyNotificationId);
  }

  /// Sends the automatic SOS alert to Firestore
  Future<void> _triggerAutomaticSos() async {
    _cancelEmergencyConfirmation();

    if (_activeChildUid == null) return;

    try {
      final position = await _locationService.getCurrentPosition();
      final alert = SosAlert(
        childUid: _activeChildUid!,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        status: 'active',
        source: 'automatic_sos',
      );

      await _firestoreService.createSosAlert(alert);

      // Show confirmation that Automatic SOS was dispatched
      const androidDetails = AndroidNotificationDetails(
        notificationChannelId,
        notificationChannelName,
        importance: Importance.max,
        priority: Priority.high,
      );
      await _notificationsPlugin.show(
        id: emergencyNotificationId + 1,
        title: 'Automatic SOS Dispatched',
        body: 'Emergency alert with your current location has been sent to your parents.',
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Failed to send Automatic SOS: $e');
    } finally {
      engine.reset();
    }
  }

  void dispose() {
    stopMonitoring();
    _countdownStreamController.close();
  }
}
