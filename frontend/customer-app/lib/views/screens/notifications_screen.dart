import 'package:flutter/material.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'package:shopease_mobile/core/routes/routes.dart';
import 'package:shopease_mobile/core/theme/app_theme.dart';
import 'package:shopease_mobile/core/utils/date_formatter.dart';
import 'package:shopease_mobile/models/customer_notification.dart';
import 'package:shopease_mobile/services/customer_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.courierMode = false});

  final bool courierMode;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final CustomerNotificationService _service = CustomerNotificationService(
    client: AppBlocProviders.apiClient,
  );
  late Future<List<CustomerNotification>> _notifications =
      _service.getNotifications();
  bool _markingAll = false;

  Future<void> _refresh() async {
    final request = _service.getNotifications();
    setState(() => _notifications = request);
    await request;
  }

  Future<void> _markAllRead(List<CustomerNotification> notifications) async {
    if (_markingAll || notifications.every((item) => item.isRead)) return;
    setState(() => _markingAll = true);
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = Future.value(
          notifications.map((item) => item.copyWith(isRead: true)).toList(),
        );
      });
    } catch (error) {
      _showMessage('Could not mark notifications as read: $error');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openNotification(CustomerNotification notification) async {
    if (!notification.isRead) {
      try {
        await _service.markRead(notification.id);
      } catch (error) {
        _showMessage('Could not update notification: $error');
        return;
      }
    }
    if (!mounted) return;
    if (!notification.isRead) {
      final current = await _notifications;
      if (mounted) {
        setState(() {
          _notifications = Future.value(
            current
                .map(
                  (item) =>
                      item.id == notification.id
                          ? item.copyWith(isRead: true)
                          : item,
                )
                .toList(),
          );
        });
      }
    }
    final orderId = notification.orderPublicId;
    if (widget.courierMode) {
      _showMessage('Check the Courier hub for your assigned task.');
      return;
    }
    if (orderId != null && orderId.isNotEmpty && mounted) {
      Navigator.of(context).pushNamed(AppRoutes.trackOrder, arguments: orderId);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.courierMode ? 'Courier notifications' : 'Notifications',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh notifications',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<CustomerNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: 'Could not load notifications.',
              action: TextButton(
                onPressed: _refresh,
                child: const Text('Retry'),
              ),
            );
          }
          final notifications = snapshot.data ?? const [];
          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 150),
                  _MessageState(
                    icon: Icons.notifications_none_rounded,
                    message: 'You are all caught up.',
                  ),
                ],
              ),
            );
          }
          final unreadCount =
              notifications.where((item) => !item.isRead).length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: notifications.length + (unreadCount > 0 ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (unreadCount > 0 && index == 0) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          _markingAll
                              ? null
                              : () => _markAllRead(notifications),
                      icon:
                          _markingAll
                              ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Mark all as read'),
                    ),
                  );
                }
                final notification =
                    notifications[index - (unreadCount > 0 ? 1 : 0)];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _openNotification(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final CustomerNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color:
          notification.isRead
              ? colors.card
              : colors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notification.notificationType == 'order_ready_for_pickup'
                    ? Icons.inventory_2_outlined
                    : Icons.notifications_active_outlined,
                color: colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: colors.foreground,
                        fontWeight:
                            notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: colors.mutedForeground,
                        fontSize: 13,
                      ),
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        DateFormatter.dateTime(notification.createdAt),
                        style: TextStyle(
                          color: colors.mutedForeground,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5, left: 8),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: context.colors.mutedForeground),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(color: context.colors.mutedForeground)),
        if (action != null) action!,
      ],
    ),
  );
}
