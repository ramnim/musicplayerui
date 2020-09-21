import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:musicplayerui/screens/search_play.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    supportedLocales: [
      Locale ('en', 'US'), // English
      Locale ('te', 'IN'), // Telugu
    ],
    localizationsDelegates: [
      AppLocale.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    localeResolutionCallback: (locale, supportedLocales) {
      for (var supportedLocalLanguage in supportedLocales) {
        if (supportedLocalLanguage.languageCode == locale.languageCode &&
            supportedLocalLanguage.countryCode == locale.countryCode) {
          return supportedLocalLanguage;
        }
      }
      return supportedLocales.first;
    },
    home: SearchPlay(),
  )
);

