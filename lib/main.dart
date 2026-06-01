import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/api/app_services.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  await AppServices.init();
  runApp(const BigLunaApp());
}

class BigLunaApp extends StatelessWidget {
  const BigLunaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppServices.localeNotifier,
      builder: (context, locale, _) {
        final colorScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6FEB),
          brightness: Brightness.light,
        );

        return MaterialApp(
          title: 'Big Luna POS',
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (deviceLocale == null) return const Locale('en');
            return supportedLocales.firstWhere(
              (supported) => supported.languageCode == deviceLocale.languageCode,
              orElse: () => const Locale('en'),
            );
          },
          theme: ThemeData(
            colorScheme: colorScheme,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F7FB),
            appBarTheme: const AppBarTheme(centerTitle: false),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
