import 'package:flutter/material.dart';

import 'legal_document_view.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  static const _lastUpdated = 'April 6, 2026';

  static final List<({String title, String body})> _sections = [
    (
      title: '1. Overview',
      body:
          'This Privacy Policy explains how Halide (“we”, “us”) collects, uses, shares, and protects information when you use our mobile application and related services (the “Service”). It should be read together with your app store terms and any in-app notices.\n\n'
          'If you do not agree with this Policy, please do not use the Service.',
    ),
    (
      title: '2. Information we collect',
      body:
          'Account & profile: email address, display name, and profile details you choose to provide; identifiers from sign-in providers (such as Apple, Google, or Facebook) when you use those options.\n\n'
          'Content & usage: film roll and gear data you enter, images and metadata you upload or sync, app interactions needed to provide features (for example sync status), and diagnostic data that helps us maintain reliability.\n\n'
          'Device & app: device type, OS version, app version, and similar technical data; where you allow it, approximate location or camera-related data used for features you turn on (such as exposure logging or metering).\n\n'
          'Purchases: subscription status and transaction identifiers as provided by Apple, Google, or our billing partner (for example RevenueCat)—we do not receive your full payment card number from those stores.\n\n'
          'Optional integrations: if you connect third-party services (such as Google Drive), we process information needed to perform the actions you request, in line with your permissions with that provider.',
    ),
    (
      title: '3. How we use information',
      body:
          'We use information to: provide, secure, and improve the Service; authenticate you; sync and store your content as you direct; process subscriptions; respond to support requests; detect abuse and fraud; comply with law; and communicate service-related messages.\n\n'
          'We do not sell your personal information. We do not use your photos for advertising profiling.',
    ),
    (
      title: '4. Legal bases (EEA/UK/Switzerland)',
      body:
          'Where GDPR or similar laws apply, we rely on: performance of a contract (providing the Service); legitimate interests (security, product improvement, aggregated analytics compatible with your rights); consent where required (for example certain optional features or marketing, if offered); and legal obligations.',
    ),
    (
      title: '5. Sharing',
      body:
          'We share information with service providers who process data on our behalf (for example hosting, authentication, billing validation, customer support tools), bound by appropriate contracts and safeguards.\n\n'
          'We may disclose information if required by law, to protect rights and safety, or as part of a merger or asset transfer with notice where required.\n\n'
          'Aggregated or de-identified information that cannot reasonably identify you may be used without restriction.',
    ),
    (
      title: '6. Retention',
      body:
          'We keep information as long as your account is active and as needed to provide the Service, unless a longer period is required by law or legitimate interests (for example security logs). You may request deletion as described below; some residual copies may persist for a short time in backups.',
    ),
    (
      title: '7. Security',
      body:
          'We use administrative, technical, and organizational measures designed to protect information. No method of transmission or storage is completely secure; we cannot guarantee absolute security.',
    ),
    (
      title: '8. International transfers',
      body:
          'We may process information in countries other than where you live. Where required, we use appropriate safeguards (such as standard contractual clauses) for transfers from the EEA, UK, or Switzerland.',
    ),
    (
      title: '9. Your choices & rights',
      body:
          'Depending on your location, you may have rights to access, correct, delete, or export personal information; object to or restrict certain processing; and withdraw consent where processing is consent-based. You may also lodge a complaint with a supervisory authority.\n\n'
          'You can manage many choices in the app or device settings (permissions, sign-in). To exercise rights, contact us through support channels listed in the app or on our site. We may verify your request as permitted by law.',
    ),
    (
      title: '10. Children',
      body:
          'The Service is not directed to children under the age required by your region to consent to data processing (often 13 or 16). We do not knowingly collect personal information from children in that category. If you believe we have, contact us and we will take appropriate steps.',
    ),
    (
      title: '11. California (U.S.)',
      body:
          'California residents may have additional rights under the CCPA/CPRA, including to know, delete, and opt out of certain sharing (we do not “sell” or “share” personal information as those terms are defined for cross-context behavioral advertising). You may designate an authorized agent where allowed by law.',
    ),
    (
      title: '12. Changes',
      body:
          'We may update this Policy and will revise the “Last updated” date. Material changes may be communicated through the app or email where appropriate.',
    ),
    (
      title: '13. Contact',
      body:
          'Questions about privacy: use the contact or support channel provided in the app or on our website, if listed.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LegalDocumentView(
      appBarTitle: 'PRIVACY POLICY',
      documentLabel: 'YOUR PRIVACY',
      sections: _sections,
      lastUpdated: _lastUpdated,
    );
  }
}
