import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../models/pos_models.dart';
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
    return AppFrame(
      title: 'System Status',
      actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
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
                    child: LoadingStateView(message: 'กำลังตรวจสถานะ...'),
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
                return Column(
                  children: [
                    GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
                      childAspectRatio: 1.65,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        StatCard(
                          label: 'Backend',
                          value: health?.ok == true ? 'Online' : 'Offline',
                          icon: health?.ok == true ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        ),
                        StatCard(
                          label: 'Connector',
                          value: health?.service ?? '-',
                          icon: Icons.device_hub_rounded,
                        ),
                        StatCard(
                          label: 'Mode',
                          value: health?.mode ?? '-',
                          icon: Icons.tune_rounded,
                        ),
                        StatCard(
                          label: 'Write mode',
                          value: health?.writeMode == false ? 'Read only' : 'Write enabled',
                          icon: health?.writeMode == false ? Icons.lock_rounded : Icons.edit_note_rounded,
                        ),
                        StatCard(
                          label: 'Database',
                          value: db?.databaseName ?? '-',
                          icon: Icons.storage_rounded,
                        ),
                        StatCard(
                          label: 'Edition',
                          value: db?.edition ?? '-',
                          icon: Icons.dataset_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Raw notes',
                      child: Column(
                        children: [
                          KeyValueRow(label: 'Message', value: health?.message ?? '-'),
                          KeyValueRow(label: 'Service', value: health?.service ?? '-'),
                          KeyValueRow(label: 'Mode', value: health?.mode ?? '-'),
                          KeyValueRow(label: 'Write mode', value: health?.writeMode == false ? 'false' : 'true'),
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
