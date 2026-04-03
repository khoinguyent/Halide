import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';

class NotificationNotifier extends Notifier<NotificationModel?> {
  @override
  NotificationModel? build() => null;

  void show(String message, {
    NotificationType type = NotificationType.info, 
    Duration duration = const Duration(seconds: 4),
  }) {
    this.state = NotificationModel(
      message: message,
      type: type,
      duration: duration,
    );
    
    // Auto-dismiss after duration
    Future.delayed(duration, () {
      if (this.state?.message == message.toUpperCase()) {
        dismiss();
      }
    });
  }

  void dismiss() {
    this.state = null;
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationModel?>(
  NotificationNotifier.new,
);
