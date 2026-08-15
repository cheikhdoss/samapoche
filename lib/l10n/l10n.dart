import 'package:flutter/widgets.dart';

import 'package:samapoche/l10n/app_localizations.dart';

export 'app_localizations.dart';

/// Accès typé aux traductions de l'app.
extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
