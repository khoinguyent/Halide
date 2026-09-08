import 'package:flutter/material.dart';

import '../../core/l10n/legal_content.dart';
import '../../core/l10n/l10n_extension.dart';
import 'legal_document_view.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;

    return LegalDocumentView(
      appBarTitle: l10n.privacyTitle,
      documentLabel: l10n.privacyDocumentLabel,
      sections: LegalContent.privacySections(languageCode),
      lastUpdated: LegalContent.privacyLastUpdated(languageCode),
    );
  }
}
