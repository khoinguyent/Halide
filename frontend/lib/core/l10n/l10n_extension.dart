import 'package:flutter/widgets.dart';
import 'package:frontend/l10n/app_localizations.dart';

extension HalideL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
