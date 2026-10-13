/// Root MaterialApp widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/localization/app_localizations.dart';
import 'providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class ClassKhataApp extends ConsumerWidget {
  const ClassKhataApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final localeCode = ref.watch(localeNotifierProvider);
    final themeMode = ref.watch(themeModeNotifierProvider);

    final locale = Locale(localeCode);
    final isRtl = localeCode == 'ur';

    return MaterialApp.router(
      title: 'ClassKhata',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
    );
  }
}
