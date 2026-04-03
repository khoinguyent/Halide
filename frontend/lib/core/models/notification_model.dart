import 'package:flutter/material.dart';

enum NotificationType { success, error, info, warning }

class NotificationModel {
  final String message;
  final NotificationType type;
  final Duration duration;

  NotificationModel({
    required this.message,
    this.type = NotificationType.info,
    this.duration = const Duration(seconds: 4),
  });
}
