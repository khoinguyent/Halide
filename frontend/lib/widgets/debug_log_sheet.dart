import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/halide_debug_log.dart';

/// Same UX as the meter debug sheet: scrollable log, copy all, clear.
///
/// [channelFilter] — when non-null, only lines for that channel are shown and copied.
void showHalideDebugLogSheet(
  BuildContext context, {
  String title = 'HALIDE DEBUG LOG',
  String? channelFilter,
  String emptyHint = '(no log lines yet — use the app, then reopen)',
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1a1a1e),
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                channelFilter == null
                    ? 'Includes meter, sync, and other diagnostics. Copy and send for support. '
                        'You can also use Xcode → Devices → Open Console, or `flutter logs`.'
                    : 'Channel: $channelFilter. Copy and send for support.',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: SingleChildScrollView(
                  child: SelectableText(
                    _displayText(channelFilter, emptyHint),
                    style: const TextStyle(
                      color: Color(0xFF86EFAC),
                      fontSize: 11,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      if (channelFilter == null) {
                        HalideDebugLog.clear();
                      } else {
                        HalideDebugLog.clearChannel(channelFilter);
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('CLEAR'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final text = _copyText(channelFilter);
                      await Clipboard.setData(ClipboardData(text: text));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('COPY ALL'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _displayText(String? channelFilter, String emptyHint) {
  final raw = channelFilter == null
      ? HalideDebugLog.allText
      : HalideDebugLog.textForChannel(channelFilter);
  return raw.isEmpty ? emptyHint : raw;
}

String _copyText(String? channelFilter) {
  final raw = channelFilter == null
      ? HalideDebugLog.allText
      : HalideDebugLog.textForChannel(channelFilter);
  return raw;
}
