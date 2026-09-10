import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/custom_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationService>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        elevation: 0,
        actions: [
          Consumer<NotificationService>(
            builder: (context, ns, _) {
              return ns.notifications.any((n) => !n.isRead)
                  ? IconButton(
                      tooltip: 'Mark all as read',
                      icon: const Icon(Icons.done_all_rounded),
                      onPressed: () => ns.markAllAsRead(),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (context, notificationService, _) {
          if (notificationService.isLoading &&
              notificationService.notifications.isEmpty) {
            return const CustomLoadingIndicator(
                message: 'Loading notifications...');
          }

          if (notificationService.errorMessage != null &&
              notificationService.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 48, color: AppColors.textGray),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      notificationService.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textGray),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => notificationService.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return notificationService.notifications.isEmpty
              ? EmptyState(
                  icon: Icons.notifications_off,
                  title: 'No Notifications',
                  message: 'You are all caught up!',
                )
              : RefreshIndicator(
                  onRefresh: () => notificationService.refresh(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: notificationService.notifications.length,
                    itemBuilder: (context, index) {
                      final notification =
                          notificationService.notifications[index];
                      return NotificationCard(
                        title: notification.title,
                        message: notification.message,
                        type: notification.type.name,
                        isRead: notification.isRead,
                        onTap: () {
                          notificationService.markAsRead(notification.id);
                        },
                        onDismiss: () {
                          notificationService
                              .deleteNotification(notification.id);
                        },
                      );
                    },
                  ),
                );
        },
      ),
    );
  }
}
