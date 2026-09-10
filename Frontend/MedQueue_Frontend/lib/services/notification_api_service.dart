import 'package:medqueue_frontend/models/notification_model.dart';
import '../models/api_response_model.dart';
import 'api_client.dart';

class NotificationApiService {
  static final NotificationApiService _instance = NotificationApiService._internal();

  factory NotificationApiService() {
    return _instance;
  }

  NotificationApiService._internal();

  /// GET /auth/notifications/
  Future<ApiResponse<NotificationListResponse>> getNotifications() async {
    return ApiClient.getWithAuth(
      '/auth/notifications/',
      parser: (json) => NotificationListResponse.fromJson(json),
    );
  }

  /// POST /auth/notifications/  {"all": true}
  Future<ApiResponse<Map<String, dynamic>>> markAllAsRead() async {
    return ApiClient.postWithAuth(
      '/auth/notifications/',
      body: {'all': true},
      parser: (json) => json,
    );
  }

  /// POST /auth/notifications/  {"id": notificationId}
  Future<ApiResponse<Map<String, dynamic>>> markAsRead(int notificationId) async {
    return ApiClient.postWithAuth(
      '/auth/notifications/',
      body: {'id': notificationId},
      parser: (json) => json,
    );
  }

  /// DELETE /auth/notifications/{id}/
  Future<ApiResponse<Map<String, dynamic>>> deleteNotification(
      int notificationId) async {
    return ApiClient.deleteWithAuth(
      '/auth/notifications/$notificationId/',
      parser: (json) => json,
    );
  }
}

class NotificationListResponse {
  final List<Notification> notifications;
  final int unreadTotal;

  NotificationListResponse({
    required this.notifications,
    required this.unreadTotal,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final List<Notification> notifications = [];
    if (json['results'] is List) {
      notifications.addAll(
        (json['results'] as List)
            .whereType<Map<String, dynamic>>()
            .map((e) => Notification.fromJson(e)),
      );
    }
    return NotificationListResponse(
      notifications: notifications,
      unreadTotal: (json['unread_total'] as num?)?.toInt() ?? 0,
    );
  }
}
