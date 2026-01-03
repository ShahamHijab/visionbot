import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/alert_model.dart';
import '../../services/alert_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final AlertService _alertService = AlertService();

  final List<NotificationItem> _synthetic = [
    NotificationItem(
      title: 'Fire Alert',
      message: 'Fire detected in Building A. Floor 2',
      time: DateTime.now().subtract(const Duration(minutes: 5)),
      type: NotificationType.critical,
      isRead: false,
    ),
    NotificationItem(
      title: 'Motion Detected',
      message: 'Unauthorized movement in restricted area',
      time: DateTime.now().subtract(const Duration(hours: 1)),
      type: NotificationType.warning,
      isRead: false,
    ),
    NotificationItem(
      title: 'System Update',
      message: 'Robot 3 completed maintenance check',
      time: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.info,
      isRead: true,
    ),
    NotificationItem(
      title: 'Smoke Alert',
      message: 'Smoke detected in parking area',
      time: DateTime.now().subtract(const Duration(hours: 4)),
      type: NotificationType.warning,
      isRead: true,
    ),
    NotificationItem(
      title: 'All Clear',
      message: 'All systems operational',
      time: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.info,
      isRead: true,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _prettyType(String raw) {
    final t = raw.toLowerCase().trim();
    if (t == 'unknown_face') return 'Unknown person';
    if (t == 'known_face') return 'Known person';
    if (t == 'motion') return 'Motion detected';
    if (t == 'fire') return 'Fire detected';
    if (t == 'smoke') return 'Smoke detected';
    if (t == 'intruder') return 'Intruder detected';

    if (t.isEmpty) return 'Alert';
    final pretty = t.replaceAll('_', ' ');
    return pretty[0].toUpperCase() + pretty.substring(1);
  }

  NotificationType _mapNotifType(String raw) {
    final t = raw.toLowerCase().trim();
    if (t == 'fire' || t == 'intruder') return NotificationType.critical;
    if (t == 'smoke' || t == 'unknown_face') return NotificationType.warning;
    return NotificationType.info;
  }

  NotificationItem _fromAlert(AlertModel alert) {
    final title = _prettyType(alert.type.toString());

    final lensText = alert.lens.isEmpty ? 'unknown lens' : alert.lens;
    final noteText = alert.note.isEmpty ? '' : alert.note;

    final message = noteText.isEmpty
        ? 'Lens: $lensText'
        : 'Lens: $lensText. $noteText';

    return NotificationItem(
      title: title,
      message: message,
      time: alert.createdAt,
      type: _mapNotifType(alert.type.toString()),
      isRead: false,
    );
  }

  void _markAllAsRead(List<NotificationItem> list) {
    setState(() {
      for (final n in list) {
        n.isRead = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AlertModel>>(
      stream: _alertService.streamAlerts(
        limit: 2,
        collection: 'alerts',
        orderField: 'created_at',
      ),
      builder: (context, snapshot) {
        final dynamicAlerts = (snapshot.data ?? []).map(_fromAlert).toList();

        final notifications = [...dynamicAlerts, ..._synthetic];

        final unreadCount = notifications.where((n) => !n.isRead).length;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF1F2937),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
              ).createShader(bounds),
              child: const Text(
                'Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            actions: [
              if (notifications.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF1F2937),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) {
                    if (value == 'mark_read') {
                      _markAllAsRead(notifications);
                    } else if (value == 'clear') {
                      setState(() {
                        _synthetic.clear();
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'mark_read',
                      child: Row(
                        children: [
                          Icon(Icons.done_all_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Mark all as read'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Clear all'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: notifications.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFEC4899).withOpacity(0.1),
                                const Color(0xFF06B6D4).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFEC4899).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFEC4899),
                                      Color(0xFF8B5CF6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'You have $unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(notifications[index]);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF06B6D4).withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                ),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    Color typeColor;
    IconData typeIcon;

    switch (notification.type) {
      case NotificationType.critical:
        typeColor = const Color(0xFFFF6B6B);
        typeIcon = Icons.warning_rounded;
        break;
      case NotificationType.warning:
        typeColor = const Color(0xFFFF9800);
        typeIcon = Icons.info_rounded;
        break;
      case NotificationType.info:
        typeColor = const Color(0xFF45B7D1);
        typeIcon = Icons.check_circle_rounded;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            notification.isRead = true;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.white
                : typeColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: notification.isRead
                  ? Colors.grey.shade200
                  : typeColor.withOpacity(0.3),
              width: notification.isRead ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(typeIcon, color: typeColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeago.format(notification.time),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationItem {
  final String title;
  final String message;
  final DateTime time;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.isRead = false,
  });
}

enum NotificationType { critical, warning, info }
