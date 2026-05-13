import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';

class NotificationNotifier extends Notifier<NotificationModel?> {
  int _token = 0;

  @override
  NotificationModel? build() => null;

  void show(String message, {
    NotificationType type = NotificationType.info, 
    Duration duration = const Duration(seconds: 4),
  }) {
    final int token = ++_token;
    state = NotificationModel(
      message: message,
      type: type,
      duration: duration,
    );
    
    // Auto-dismiss after duration
    Future.delayed(duration, () {
      if (_token == token) {
        dismiss();
      }
    });
  }

  void dismiss() {
    _token++;
    state = null;
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationModel?>(
  NotificationNotifier.new,
);
