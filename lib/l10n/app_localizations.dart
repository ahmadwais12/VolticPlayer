import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App localization support for English, Dari/Persian, Pashto, Arabic, and Urdu.
class AppLocalizations {
  final Locale locale;
  late Map<String, String> _strings;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fa'),
    Locale('ps'),
    Locale('ar'),
    Locale('ur'),
  ];

  bool get isRtl =>
      locale.languageCode == 'fa' ||
      locale.languageCode == 'ps' ||
      locale.languageCode == 'ar' ||
      locale.languageCode == 'ur';

  Future<void> load() async {
    final jsonString =
        await rootBundle.loadString('lib/l10n/app_${locale.languageCode}.arb');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    _strings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
  }

  String translate(String key) => _strings[key] ?? key;

  // Convenience getters
  String get appTitle => translate('appTitle');
  String get home => translate('home');
  String get videos => translate('videos');
  String get music => translate('music');
  String get folders => translate('folders');
  String get settings => translate('settings');
  String get search => translate('search');
  String get favorites => translate('favorites');
  String get history => translate('history');
  String get bookmarks => translate('bookmarks');
  String get downloads => translate('downloads');
  String get playlists => translate('playlists');
  String get equalizer => translate('equalizer');
  String get nowPlaying => translate('nowPlaying');
  String get noVideosFound => translate('noVideosFound');
  String get cancel => translate('cancel');
  String get delete => translate('delete');
  String get save => translate('save');
  String get close => translate('close');
  String get retry => translate('retry');
  String get aspectRatio => translate('aspectRatio');
  String get mediaInformation => translate('mediaInformation');
  String get sleepTimer => translate('sleepTimer');
  String get shuffle => translate('shuffle');
  String get repeat => translate('repeat');
  String get queue => translate('queue');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fa', 'ps', 'ar', 'ur'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
