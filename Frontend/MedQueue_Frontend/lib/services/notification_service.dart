import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'notification_api_service.dart';

/// API-backed in-app notification service.
class NotificationService extends ChangeNotifier {
  final NotificationApiService _apiService = NotificationApiService();

  List<Notification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _unreadTotal = 0;
  Timer? _pollTimer;
  final Duration _pollInterval = const Duration(seconds: 30);
  bool _authenticated = false;
  int _sessionGeneration = 0;

  List<Notification> get notifications => _notifications;
  List<Notification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadTotal;

  /// Called when the user logs in / session is restored.
  /// Guarded so repeated calls (e.g. wrappers that rebuild) don't re-trigger
  /// reloads, and so a stale in-flight refresh from a previous user can
  /// never land on the wrong user's inbox.
  void setAuthenticated(bool value) {
    if (_authenticated == value) return; // no-op on repeated build calls
    _authenticated = value;
    if (value) {
      _sessionGeneration++; // invalidate any in-flight refresh from before
      refresh(initial: true);
    }
  }

  void clearState() {
    _authenticated = false;
    _sessionGeneration++; // drop any in-flight refresh from the old session
    _stopPolling();
    _notifications = [];
    _unreadTotal = 0;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh({bool initial = false}) async {
    if (!_authenticated) return;
    if (_isLoading && !initial) return;

    final generation = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    if (initial) notifyListeners();

    try {
      final response = await _apiService.getNotifications();
      // A newer login/logout happened while we were waiting — discard.
      if (generation == _sessionGeneration) {
        if (response.isSuccess && response.data != null) {
          _notifications = response.data!.notifications;
          _unreadTotal = response.data!.unreadTotal;
        } else {
          _errorMessage = response.message;
        }
      }
    } catch (e) {
      if (generation == _sessionGeneration) {
        _errorMessage = 'Failed to load notifications: ${e.toString()}';
      }
    } finally {
      if (generation == _sessionGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Start periodic polling for the authenticated user.
  void startPolling() {
    if (_pollTimer != null || !_authenticated) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      refresh();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  Future<void> markAsRead(int notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && _notifications[index].isRead) return;

    _notifications = _notifications
        .map((n) => n.id == notificationId
            ? Notification(
                id: n.id,
                userId: n.userId,
                title: n.title,
                message: n.message,
                type: n.type,
                isRead: true,
                createdAt: n.createdAt,
                actionUrl: n.actionUrl,
                metadata: n.metadata,
              )
            : n)
        .toList();
    _unreadTotal = _notifications.where((n) => !n.isRead).length;
    notifyListeners();

    await _apiService.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    if (_notifications.every((n) => n.isRead)) return;

    _notifications = _notifications
        .map((n) => Notification(
              id: n.id,
              userId: n.userId,
              title: n.title,
              message: n.message,
              type: n.type,
              isRead: true,
              createdAt: n.createdAt,
              actionUrl: n.actionUrl,
              metadata: n.metadata,
            ))
        .toList();
    _unreadTotal = 0;
    notifyListeners();

    await _apiService.markAllAsRead();
  }

  Future<void> deleteNotification(int notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    _unreadTotal = _notifications.where((n) => !n.isRead).length;
    notifyListeners();

    await _apiService.deleteNotification(notificationId);
  }
}
