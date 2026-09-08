import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../core/l10n/legal_content.dart';
import '../../core/l10n/l10n_extension.dart';
import 'legal_document_view.dart';

class TermsConditionsView extends StatelessWidget {
  const TermsConditionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;

    return LegalDocumentView(
      appBarTitle: l10n.termsTitle,
      documentLabel: l10n.termsDocumentLabel,
      belowDocumentLabel: Builder(
        builder: (context) {
          final linkL10n = context.l10n;
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse(AppConfig.appleStandardEulaUrl);
                final ok =
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!context.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(linkL10n.couldNotOpenLink)),
                  );
                }
              },
              icon: Icon(
                Icons.open_in_new,
                size: 18,
                color: Colors.lightBlueAccent.withValues(alpha: 0.9),
              ),
              label: Text(
                linkL10n.viewAppleEula,
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
          );
        },
      ),
      sections: LegalContent.termsSections(languageCode),
      lastUpdated: LegalContent.termsLastUpdated(languageCode),
    );
  }
}
