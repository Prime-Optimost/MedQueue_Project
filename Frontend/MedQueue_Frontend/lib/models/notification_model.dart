enum NotificationType { appointment, queue, emergency, message, reminder }

class Notification {
  final int id;
  final int userId;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.actionUrl,
    this.metadata,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['recipient_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: _typeFromString(json['type'] as String?),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      actionUrl: json['action_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static NotificationType _typeFromString(String? type) {
    switch (type) {
      case 'appointment':
        return NotificationType.appointment;
      case 'queue':
        return NotificationType.queue;
      case 'emergency':
        return NotificationType.emergency;
      case 'message':
        return NotificationType.message;
      case 'reminder':
        return NotificationType.reminder;
      default:
        return NotificationType.message;
    }
  }
}
