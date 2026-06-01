import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../models/pos_models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late Future<SystemSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = AppServices.api.getSystemSnapshot();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = AppServices.api.getSystemSnapshot();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFrame(
      title: l10n.systemStatus,
      actions: [IconButton(tooltip: l10n.refresh, onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FutureBuilder<SystemSnapshot>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: LoadingStateView(message: 'Loading system status...'),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh),
                  );
                }

                final health = snapshot.data?.health;
                final db = snapshot.data?.databaseInfo;
                final statusText = health?.ok == true ? l10n.backendOnline : l10n.backendOffline;
                final connectorText = health?.service.isNotEmpty == true ? health!.service : l10n.notProvidedByApi;
                final modeText = health?.mode.isNotEmpty == true ? health!.mode : l10n.notProvidedByApi;
                final writeText = health == null ? l10n.notProvidedByApi : (health.writeMode ? l10n.writeEnabled : l10n.readOnly);
                final databaseText = db?.databaseName.isNotEmpty == true ? db!.databaseName : l10n.notProvidedByApi;
                final editionText = db?.edition?.isNotEmpty == true ? db!.edition! : l10n.notProvidedByApi;
                return Column(
                  children: [
                    GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
                      mainAxisExtent: 136,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        StatCard(
                          label: 'Backend',
                          value: statusText,
                          icon: health?.ok == true ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        ),
                        StatCard(
                          label: 'Connector',
                          value: connectorText,
                          icon: Icons.device_hub_rounded,
                        ),
                        StatCard(
                          label: 'Mode',
                          value: modeText,
                          icon: Icons.tune_rounded,
                        ),
                        StatCard(
                          label: 'Write mode',
                          value: writeText,
                          icon: health?.writeMode == false ? Icons.lock_rounded : Icons.edit_note_rounded,
                        ),
                        StatCard(
                          label: 'Database',
                          value: databaseText,
                          icon: Icons.storage_rounded,
                        ),
                        StatCard(
                          label: 'Edition',
                          value: editionText,
                          icon: Icons.dataset_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'API notes',
                      child: Column(
                        children: [
                          KeyValueRow(label: 'Message', value: health?.message ?? l10n.notProvidedByApi),
                          KeyValueRow(label: 'Service', value: health?.service ?? l10n.notProvidedByApi),
                          KeyValueRow(label: 'Mode', value: health?.mode ?? l10n.notProvidedByApi),
                          KeyValueRow(label: 'Write mode', value: health == null ? l10n.notProvidedByApi : (health.writeMode ? 'true' : 'false')),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
