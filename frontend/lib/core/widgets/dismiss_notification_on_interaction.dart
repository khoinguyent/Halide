import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';

/// Dismisses the in-app toast notification as soon as the user interacts
/// anywhere (tap/drag/scroll/keyboard), to avoid stale notifications lingering.
class DismissNotificationOnInteraction extends ConsumerStatefulWidget {
  const DismissNotificationOnInteraction({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<DismissNotificationOnInteraction> createState() => _DismissNotificationOnInteractionState();
}

class _DismissNotificationOnInteractionState extends ConsumerState<DismissNotificationOnInteraction> {
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'dismiss-notification-keyboard');

  void _dismissIfShowing() {
    if (ref.read(notificationProvider) != null) {
      ref.read(notificationProvider.notifier).dismiss();
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _dismissIfShowing(),
      onPointerSignal: (_) => _dismissIfShowing(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification || n is UserScrollNotification) {
            _dismissIfShowing();
          }
          return false;
        },
        child: KeyboardListener(
          focusNode: _keyboardFocusNode,
          onKeyEvent: (_) {
            _dismissIfShowing();
          },
          child: widget.child,
        ),
      ),
    );
  }
}

