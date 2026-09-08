import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';

import '../core/widgets/halide_scaffold.dart';
import '../providers/auth_provider.dart';

class SupportView extends ConsumerWidget {
  const SupportView({super.key});

  static const String _supportEmail = 'feedback@halide.io.vn';

  Future<void> _composeEmail({
    required BuildContext context,
    required String subject,
    required String body,
  }) async {
    final l10n = context.l10n;
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: <String, String>{
        'subject': subject,
        'body': body,
      },
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unableToOpenEmail)),
      );
    }
  }

  String _emailBody(AppLocalizations l10n, String email, String uid, String placeholder) {
    return [
      l10n.emailGreeting,
      '',
      placeholder,
      '',
      l10n.emailBodySeparator,
      l10n.emailAccountLine(email),
      l10n.emailUserIdLine(uid),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final authService = ref.watch(authServiceProvider);
    final u = authService.currentUser;
    final uid = u?.uid ?? '';
    final email = u?.email ?? '';
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return HalideScaffold(
      appBar: AppBar(
        title: Text(
          l10n.supportTitle,
          style: const TextStyle(
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Padding(
        // This view is usually displayed inside the shell, where the bottom
        // glass dock sits above the content. Add padding so the tip isn't
        // hidden under the dock.
        padding: EdgeInsets.fromLTRB(24, 16, 24, safeBottom + 64 + 24 + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.supportHeadline,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.supportDescription(_supportEmail),
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _composeEmail(
                  context: context,
                  subject: l10n.supportEmailSubject,
                  body: _emailBody(l10n, email, uid, l10n.supportEmailBodyPlaceholder),
                );
              },
              child: Text(l10n.contactSupport),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                _composeEmail(
                  context: context,
                  subject: l10n.feedbackEmailSubject,
                  body: _emailBody(l10n, email, uid, l10n.feedbackEmailBodyPlaceholder),
                );
              },
              child: Text(l10n.sendFeedback),
            ),
            const Spacer(),
            Text(
              l10n.supportTip,
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
