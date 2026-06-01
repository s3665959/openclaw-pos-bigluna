import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = AppServices.localeNotifier.value;
    return AppFrame(
      title: l10n.settings,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: l10n.settingsLanguage,
            subtitle: 'Choose the UI language for this device.',
            child: DropdownButtonFormField<Locale>(
              initialValue: current,
              decoration: const InputDecoration(
                labelText: 'Language',
                prefixIcon: Icon(Icons.language_rounded),
              ),
              items: [
                DropdownMenuItem(value: AppServices.englishLocale, child: Text(l10n.englishLabel)),
                DropdownMenuItem(value: AppServices.vietnameseLocale, child: Text(l10n.vietnameseLabel)),
              ],
              onChanged: (locale) {
                if (locale != null) {
                  AppServices.setLocale(locale);
                  setState(() {});
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Demo mode',
            subtitle: AppServices.config.demoReadOnly
                ? l10n.demoModeDisabledBanner
                : l10n.demoModeEnabledBanner,
            child: Text(
              AppServices.config.demoReadOnly
                  ? 'Write actions are blocked.'
                  : 'Write actions are enabled for the POS test environment.',
            ),
          ),
        ],
      ),
    );
  }
}
