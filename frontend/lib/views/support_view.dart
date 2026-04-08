import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
        const SnackBar(content: Text('Unable to open your email app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final u = authService.currentUser;
    final uid = u?.uid ?? '';
    final email = u?.email ?? '';

    return HalideScaffold(
      appBar: AppBar(
        title: const Text(
          'SUPPORT',
          style: TextStyle(
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'We read every message.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send your feedback, bug reports, and feature requests to $_supportEmail.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final body = [
                  'Hi Halide team,',
                  '',
                  '(Describe what happened / what you need)',
                  '',
                  '—',
                  'Account: $email',
                  'User ID: $uid',
                ].join('\n');
                _composeEmail(
                  context: context,
                  subject: 'Halide Support',
                  body: body,
                );
              },
              child: const Text('Contact Support'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                final body = [
                  'Hi Halide team,',
                  '',
                  '(Tell us what you loved / what you want improved)',
                  '',
                  '—',
                  'Account: $email',
                  'User ID: $uid',
                ].join('\n');
                _composeEmail(
                  context: context,
                  subject: 'Halide Feedback',
                  body: body,
                );
              },
              child: const Text('Send Feedback'),
            ),
            const Spacer(),
            Text(
              'Tip: screenshots help a lot.',
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

