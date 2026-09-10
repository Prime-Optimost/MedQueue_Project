import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes/app_routes.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';

/// A notification bell icon with an unread badge that navigates to the
/// notifications screen. Uses role-appropriate foreground color.
class NotificationBell extends StatelessWidget {
  final Color color;
  final String routeName;

  const NotificationBell({
    super.key,
    this.color = Colors.white,
    this.routeName = AppRoutes.patientNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationService>(
      builder: (context, notificationService, _) {
        final unread = notificationService.unreadCount;
        return IconButton(
          tooltip: 'Notifications',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_rounded, color: color),
              if (unread > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.emergencyRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            Navigator.pushNamed(context, routeName);
          },
        );
      },
    );
  }
}
