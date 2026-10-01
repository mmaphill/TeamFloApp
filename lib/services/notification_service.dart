import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/log.dart';
import '../main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission (iOS will show a dialog; Android auto-grants)
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Initialize local notifications for foreground display
    await _initializeLocalNotifications();

    // App open: show a banner
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App in background: user tapped the notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      log('Opened from background: ${message.data}');
    });
  }

  // App was fully closed and opened by tapping a notification
  // Call once after the first frame so the navigator exist
  Future<void> handleInitialMessage() async {
    final message = await _firebaseMessaging.getInitialMessage();
    if (message == null) return;

    // wait for firebase auth to restore the logged-in user
    await FirebaseAuth.instance.authStateChanges().first;

    log('Opened from terminated: ${message.data}');
    _navigateFromData(message.data);
  }

  // Gets the current FCM token and saves it for the logged-in user.
  Future<void> saveCurrentToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        log('No FCM token available yet');
        return;
      }
      await _saveTokenToFirestore(token);
    } catch (e) {
      log('Error getting FCM token: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iOSSettings =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
  }

  void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      _navigateFromData(data);
    } catch (e) {
      log('Could not read notification payload: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    log('Foreground message: ${message.notification?.title}');

    // Display a local notification while app is open
    _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'team_flo_channel',
          'Team Flo Notifications',
          channelDescription: 'Notifications for Team Flo BJJ app',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  // One place that decides where a notification goes
  // Used by all three cases: foreground, background, and closed.
  void _navigateFromData(Map<String, dynamic> data) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      log('Navigator not ready, skipping notification navigation');
      return;
    }

    // Never skip past the login screen
    if (FirebaseAuth.instance.currentUser == null) return;

    final type = data['type'];

    if (type == 'tag') {
      final postId = data['postId'] as String?;
      navigator.popUntil((route) => route.isFirst);
      navigator.pushNamed('/chat', arguments: postId);
    } else if (type == 'workout_reminder') {
      final classId = data['classId'] as String?;
      navigator.popUntil((route) => route.isFirst);
      navigator.pushNamed('/journal', arguments: classId);
    } else {
      log('Unknown notification type $type');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      log('User not authenticated, skipping token save');
      return;
    }

    try {
      // set + merge works even if the field doesn't exist yet
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      log('Error saving token: $e');
    }
  }

  void listenForTokenRefresh() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      log('Token refreshed');
      _saveTokenToFirestore(newToken);
    });
  }
}


// Runs in a separate isolate when a message arrives in the background
// Must be top-level, public, and marked so release builds keep it
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('Background message: ${message.notification?.title}');
}