import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';

class HalideNotification extends ConsumerWidget {
  const HalideNotification({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notification = ref.watch(notificationProvider);
    if (notification == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: -100.0, end: 0.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, value),
              child: Opacity(
                opacity: (value + 100) / 100,
                child: child,
              ),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getColor(notification.type).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _getIcon(notification.type),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          notification.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ref.read(notificationProvider.notifier).dismiss(),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor(NotificationType type) {
    switch (type) {
      case NotificationType.success: return Colors.greenAccent;
      case NotificationType.error: return Colors.redAccent;
      case NotificationType.info: return Colors.blueAccent;
      case NotificationType.warning: return Colors.orangeAccent;
    }
  }

  Widget _getIcon(NotificationType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.success:
        iconData = Icons.check_circle_outline_rounded;
        color = Colors.greenAccent;
        break;
      case NotificationType.error:
        iconData = Icons.error_outline_rounded;
        color = Colors.redAccent;
        break;
      case NotificationType.info:
        iconData = Icons.info_outline_rounded;
        color = Colors.blueAccent;
        break;
      case NotificationType.warning:
        iconData = Icons.warning_amber_rounded;
        color = Colors.orangeAccent;
        break;
    }

    return Icon(iconData, color: color, size: 20);
  }
}
