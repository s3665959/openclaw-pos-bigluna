import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'products_screen.dart';
import 'sales_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Big Luna POS'),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.language_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF6F0FF),
              Color(0xFFF2EEFF),
              Color(0xFFFCFAFF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A6F5AA8),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E7FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Mobile Point of Sale',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6E5AA6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Big Luna POS',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2E1F4F),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fast access to the mobile demo workflows.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B6280),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _HomeMenuCard(
                title: l10n.scanBarcode,
                subtitle: 'Open camera and search products instantly',
                icon: Icons.qr_code_scanner_rounded,
                accent: const Color(0xFF8D6DFF),
                foreground: Colors.white,
                background: const LinearGradient(
                  colors: [
                    Color(0xFF8D6DFF),
                    Color(0xFFB08CFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
              ),
              const SizedBox(height: 14),
              _HomeMenuCard(
                title: l10n.products,
                subtitle: 'Search, edit, and manage product details',
                icon: Icons.inventory_2_rounded,
                accent: const Color(0xFF7D57D1),
                foreground: const Color(0xFF2E1F4F),
                background: const LinearGradient(
                  colors: [
                    Colors.white,
                    Color(0xFFF9F5FF),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderColor: const Color(0xFFE5D8FF),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductsScreen())),
              ),
              const SizedBox(height: 14),
              _HomeMenuCard(
                title: l10n.sales,
                subtitle: 'Review live sales activity and records',
                icon: Icons.point_of_sale_rounded,
                accent: const Color(0xFF7D57D1),
                foreground: const Color(0xFF2E1F4F),
                background: const LinearGradient(
                  colors: [
                    Colors.white,
                    Color(0xFFF9F5FF),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderColor: const Color(0xFFE5D8FF),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesScreen())),
              ),
              const SizedBox(height: 14),
              _HomeMenuCard(
                title: l10n.systemStatus,
                subtitle: 'View backend, connector, and database status',
                icon: Icons.monitor_heart_rounded,
                accent: scheme.primary,
                foreground: const Color(0xFF2E1F4F),
                background: const LinearGradient(
                  colors: [
                    Colors.white,
                    Color(0xFFF7F3FF),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderColor: const Color(0xFFE5D8FF),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatusScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMenuCard extends StatelessWidget {
  const _HomeMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.borderColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color foreground;
  final Gradient background;
  final VoidCallback onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: background,
            borderRadius: BorderRadius.circular(28),
            border: borderColor == null ? null : Border.all(color: borderColor!),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: foreground == Colors.white ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFF0E7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: foreground, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: foreground,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: foreground.withValues(alpha: foreground == Colors.white ? 0.92 : 0.72),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: foreground == Colors.white ? Colors.white : accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
