import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import 'legal_document_view.dart';

class TermsConditionsView extends StatelessWidget {
  const TermsConditionsView({super.key});

  static const _lastUpdated = 'April 20, 2026';

  static final List<({String title, String body})> _sections = [
    (
      title: '1. Licensed application (Apple Standard EULA)',
      body:
          'Apps distributed through the Apple App Store are licensed, not sold, to you. Your license to the Halide iOS application is subject to your acceptance of Apple’s Licensed Application End User License Agreement (the “Standard EULA”), unless Apple offers a custom end user license agreement for the app.\n\n'
          'The full Standard EULA is published by Apple at:\n${AppConfig.appleStandardEulaUrl}\n\n'
          'For the Halide app obtained from the App Store, the Standard EULA (and not a separate Halide EULA) is the primary license agreement for the application as between you and Apple, as described in that document.',
    ),
    (
      title: '2. Supplemental terms (Halide Service)',
      body:
          'The following sections are supplemental terms between you and Halide regarding the Halide mobile application and related online services (collectively, the “Service”). They apply in addition to the Apple Standard EULA (where applicable), your app store’s rules, and our Privacy Policy. If you do not agree, do not use the Service.\n\n'
          'We may update these supplemental terms from time to time. We will indicate the “Last updated” date at the bottom of this screen. Continued use after changes constitutes acceptance of the revised terms, except where applicable law requires additional consent.',
    ),
    (
      title: '3. The Service',
      body:
          'Halide helps you manage analog film photography workflows, including gear and roll tracking, exposure-related tools, optional cloud sync of your content, and integrations you enable (such as linked cloud storage). Features may differ by platform or subscription tier.\n\n'
          'We may add, change, or discontinue features with reasonable notice where practicable. The Service is provided for personal, non-commercial use unless we agree otherwise in writing.',
    ),
    (
      title: '4. Accounts & eligibility',
      body:
          'You must provide accurate registration information and keep your credentials secure. You are responsible for activity under your account. You must be old enough to enter a binding contract where you live (and at least the age required by your app store). Notify us promptly if you suspect unauthorized access.',
    ),
    (
      title: '5. Acceptable use',
      body:
          'You agree not to misuse the Service. Without limitation, you must not: violate law or third-party rights; attempt to probe, scan, or test vulnerabilities; interfere with or overload the Service; use automated means to scrape or bulk-collect data without permission; reverse engineer except as allowed by law; upload malware; impersonate others; or use the Service to harass or harm others.\n\n'
          'We may suspend or terminate access for violations or risk to the Service or other users.',
    ),
    (
      title: '6. Your content',
      body:
          'You retain ownership of content you submit (for example roll metadata, images, and notes). To operate the Service, you grant Halide a worldwide, non-exclusive license to host, process, transmit, display, and back up your content solely to provide and improve the Service for you, including security and abuse prevention.\n\n'
          'You represent that you have the rights needed to upload your content and that it does not infringe others’ rights. Exposure and metering tools are informational; you remain responsible for creative and technical decisions in the field.',
    ),
    (
      title: '7. Subscriptions & purchases',
      body:
          'Paid features may be offered through in-app purchases processed by Apple App Store, Google Play, or other platforms. Pricing, renewal, cancellation, and refunds are governed by the applicable store’s policies and your payment provider. Subscription status may be validated through our billing partner (for example RevenueCat).\n\n'
          'If a payment fails or a subscription ends, access to paid features may change in line with your account status.',
    ),
    (
      title: '8. Third-party services',
      body:
          'The Service may rely on or link to third parties (including authentication, analytics, cloud infrastructure, storage providers, and optional integrations such as Google Drive). Their use is subject to their respective terms and privacy policies. We are not responsible for third-party services we do not control.',
    ),
    (
      title: '9. Disclaimers',
      body:
          'THE SERVICE IS PROVIDED “AS IS” AND “AS AVAILABLE” WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT, TO THE MAXIMUM EXTENT PERMITTED BY LAW.\n\n'
          'We do not guarantee uninterrupted or error-free operation. Tools that rely on device sensors or estimates (such as light metering) are approximate and depend on conditions and hardware; they are not a substitute for professional judgment or dedicated hardware where required.',
    ),
    (
      title: '10. Limitation of liability',
      body:
          'TO THE MAXIMUM EXTENT PERMITTED BY LAW, HALIDE AND ITS AFFILIATES, DIRECTORS, EMPLOYEES, AND SUPPLIERS WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS, DATA, OR GOODWILL, ARISING OUT OF OR RELATED TO THE SERVICE OR THESE SUPPLEMENTAL TERMS.\n\n'
          'OUR TOTAL LIABILITY FOR ANY CLAIM ARISING OUT OF THE SERVICE OR THESE SUPPLEMENTAL TERMS IS LIMITED TO THE GREATER OF (A) THE AMOUNTS YOU PAID US FOR THE SERVICE IN THE TWELVE (12) MONTHS BEFORE THE CLAIM OR (B) FIFTY U.S. DOLLARS (US\$50), EXCEPT WHERE PROHIBITED BY LAW.',
    ),
    (
      title: '11. Indemnity',
      body:
          'You will defend and indemnify Halide and its affiliates against third-party claims and costs (including reasonable attorneys’ fees) arising from your content, your use of the Service, or your violation of these supplemental terms or applicable law, except to the extent caused by our willful misconduct.',
    ),
    (
      title: '12. Termination',
      body:
          'You may stop using the Service at any time. We may suspend or terminate access if you breach these supplemental terms, if we must comply with law, or to protect the Service or users. Provisions that by their nature should survive (including ownership, disclaimers, limitations, and indemnity) will survive termination.',
    ),
    (
      title: '13. Governing law & disputes',
      body:
          'Unless mandatory local law requires otherwise, these supplemental terms are governed by the laws applicable in your primary place of residence’s jurisdiction for consumer contracts, without regard to conflict-of-law rules. Courts in that jurisdiction may have exclusive jurisdiction over disputes, unless you have mandatory rights elsewhere.',
    ),
    (
      title: '14. Contact',
      body:
          'Questions about these supplemental terms: use the contact or support channel provided in the app or on our website, if listed.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LegalDocumentView(
      appBarTitle: 'TERMS & CONDITIONS',
      documentLabel: 'TERMS OF SERVICE',
      belowDocumentLabel: Builder(
        builder: (context) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final uri = Uri.parse(AppConfig.appleStandardEulaUrl);
              final ok =
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open link.')),
                );
              }
            },
          icon: Icon(
            Icons.open_in_new,
            size: 18,
            color: Colors.lightBlueAccent.withValues(alpha: 0.9),
          ),
          label: Text(
            'View Apple Standard EULA',
            style: TextStyle(
              color: Colors.lightBlueAccent.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: Colors.lightBlueAccent,
          ),
        ),
        ),
      ),
      sections: _sections,
      lastUpdated: _lastUpdated,
    );
  }
}
