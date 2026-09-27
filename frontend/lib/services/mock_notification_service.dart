import 'package:flutter/material.dart';

class NotificationPayload {
  final String id;
  final String title;
  final String body;
  final String targetRoute; // '/beranda'
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  NotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    this.targetRoute = '/beranda',
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();
}

class MockNotificationService extends ChangeNotifier {
  static final MockNotificationService _instance = MockNotificationService._();
  static MockNotificationService get instance => _instance;

  MockNotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  NotificationPayload? _currentNotification;
  final List<NotificationPayload> _history = [];

  NotificationPayload? get currentNotification => _currentNotification;
  List<NotificationPayload> get history => List.unmodifiable(_history);

  /// Simulate receiving a reminder notification
  NotificationPayload showReminderNotification({
    String? id,
    String? title,
    String? body,
    String targetRoute = '/beranda',
    Map<String, dynamic>? data,
  }) {
    final payload = NotificationPayload(
      id: id ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'Moneta AI • Saran Belanja Hari Ini',
      body: body ??
          'Batas belanja aman Anda hari ini Rp 65.000. Ketuk untuk membuka Beranda dan melihat saran lengkap.',
      targetRoute: targetRoute,
      data: data,
    );

    _currentNotification = payload;
    _history.insert(0, payload);
    notifyListeners();
    return payload;
  }

  /// Handle clicking on the notification -> direct to Beranda
  bool handleNotificationClick({
    NotificationPayload? payload,
    BuildContext? context,
  }) {
    final target = payload ?? _currentNotification;
    final route = target?.targetRoute ?? '/beranda';

    _currentNotification = null;
    notifyListeners();

    if (context != null) {
      Navigator.of(context).pushNamed(route);
      return true;
    } else if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamed(route);
      return true;
    }
    return false;
  }

  /// Dismiss active notification without opening target
  void dismissCurrentNotification() {
    _currentNotification = null;
    notifyListeners();
  }

  /// Reset service state for clean testing
  void resetForTesting() {
    _currentNotification = null;
    _history.clear();
    notifyListeners();
  }
}
