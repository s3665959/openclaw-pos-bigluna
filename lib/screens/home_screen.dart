import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';
import 'inventory_screen.dart';
import 'products_screen.dart';
import 'purchase_orders_screen.dart';
import 'sales_screen.dart';
import 'scan_screen.dart';
import 'status_screen.dart';
import 'vendors_screen.dart';
import 'operations_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeSnapshot> _load() async {
    final api = AppServices.api;
    final results = await Future.wait<Object?>([
      _loadResult(() => api.getSystemSnapshot()),
      _loadResult(() => api.getProductCount()),
      _loadResult(() => api.getTodaySalesSummary()),
    ]);
    return _HomeSnapshot(
      systemSnapshot: results[0] as _LoadResult<SystemSnapshot>,
      productCount: results[1] as _LoadResult<int>,
      salesSummary: results[2] as _LoadResult<SalesSummary>,
    );
  }

  Future<_LoadResult<T>> _loadResult<T>(Future<T> Function() loader) async {
    try {
      return _LoadResult<T>(data: await loader());
    } catch (error) {
      return _LoadResult<T>(error: error);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFrame(
      title: l10n.appName,
      actions: [
        IconButton(
          tooltip: l10n.systemStatus,
          icon: const Icon(Icons.monitor_heart_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatusScreen())),
        ),
        IconButton(
          tooltip: l10n.settings,
          icon: const Icon(Icons.language_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_HomeSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 120),
                  LoadingStateView(message: l10n.loadingDashboard),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  ErrorStateView(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  ),
                ],
              );
            }

            final data = snapshot.data;
            final health = data?.systemSnapshot.data?.health;
            final db = data?.systemSnapshot.data?.databaseInfo;
            final writeMode = health?.writeMode ?? false;
            final statusLabel = health == null
                ? l10n.notProvidedByApi
                : health.ok
                    ? (writeMode ? l10n.writeEnabled : l10n.readOnly)
                    : l10n.backendOffline;
            final statusColor = health == null
                ? Theme.of(context).colorScheme.outline
                : health.ok
                    ? (writeMode ? Colors.green : Colors.orange)
                    : Colors.red;
            final productCountText = data?.productCount.data != null
                ? '${data!.productCount.data}'
                : l10n.notProvidedByApi;
            final productCountSubtitle = data?.productCount.error == null ? '/products/count' : 'API error';
            final salesSummary = data?.salesSummary.data;
            final salesText = salesSummary != null ? formatMoney(salesSummary.totalSalesAmount) : l10n.notProvidedByApi;
            final salesSubtitle = salesSummary != null
                ? '${salesSummary.transactionCount} orders'
                : 'API error';
            final databaseName = db?.databaseName.isNotEmpty == true ? db!.databaseName : l10n.notProvidedByApi;
            final editionText = db?.edition?.isNotEmpty == true ? db!.edition! : l10n.notProvidedByApi;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                SectionCard(
                  title: l10n.dashboardOverview,
                  subtitle: 'Connected to the live OpenClaw backend/API via .env',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          InfoPill(label: statusLabel, color: statusColor),
                          InfoPill(label: 'DB: $databaseName'),
                          InfoPill(label: 'Mode: ${health?.mode ?? l10n.notProvidedByApi}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
                        mainAxisExtent: 136,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          StatCard(
                            label: l10n.products,
                            value: productCountText,
                            icon: Icons.inventory_2_rounded,
                            subtitle: productCountSubtitle,
                          ),
                          StatCard(
                            label: 'Today sales',
                            value: salesText,
                            icon: Icons.receipt_long_rounded,
                            subtitle: salesSubtitle,
                          ),
                          StatCard(
                            label: 'Database',
                            value: databaseName,
                            icon: Icons.storage_rounded,
                            subtitle: editionText,
                          ),
                          StatCard(
                            label: 'Write access',
                            value: writeMode ? l10n.writeEnabled : l10n.readOnly,
                            icon: writeMode ? Icons.edit_note_rounded : Icons.lock_rounded,
                            subtitle: health?.service ?? l10n.notProvidedByApi,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.demoMenu, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                FeatureTile(
                  title: l10n.products,
                  subtitle: 'Search and view product / stock details',
                  icon: Icons.inventory_2_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductsScreen())),
                ),
                FeatureTile(
                  title: l10n.scanBarcode,
                  subtitle: 'Open the camera and search by barcode',
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
                ),
                FeatureTile(
                  title: l10n.inventory,
                  subtitle: 'View low / out / negative stock and search',
                  icon: Icons.warehouse_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryScreen())),
                ),
                FeatureTile(
                  title: l10n.sales,
                  subtitle: 'Today sales and live backend records',
                  icon: Icons.point_of_sale_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesScreen())),
                ),
                FeatureTile(
                  title: l10n.vendors,
                  subtitle: 'Vendor list and live details',
                  icon: Icons.people_alt_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VendorsScreen())),
                ),
                FeatureTile(
                  title: l10n.purchaseOrders,
                  subtitle: 'PO list and receiving detail',
                  icon: Icons.receipt_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen())),
                ),
                FeatureTile(
                  title: l10n.goodsReceiving,
                  subtitle: 'View receiving docs and status',
                  icon: Icons.local_shipping_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OperationsScreen(section: OperationsSection.goodsReceiving))),
                ),
                FeatureTile(
                  title: l10n.stockAdjustment,
                  subtitle: 'Adjust stock with confirmation before API submit',
                  icon: Icons.swap_vert_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OperationsScreen(section: OperationsSection.stockAdjustment))),
                ),
                FeatureTile(
                  title: l10n.expiryLots,
                  subtitle: 'View and add expiry lots supported by backend',
                  icon: Icons.event_busy_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OperationsScreen(section: OperationsSection.expiryLots))),
                ),
                FeatureTile(
                  title: l10n.systemStatus,
                  subtitle: 'Backend, connector, and database status',
                  icon: Icons.monitor_heart_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatusScreen())),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeSnapshot {
  const _HomeSnapshot({
    required this.systemSnapshot,
    required this.productCount,
    required this.salesSummary,
  });

  final _LoadResult<SystemSnapshot> systemSnapshot;
  final _LoadResult<int> productCount;
  final _LoadResult<SalesSummary> salesSummary;
}

class _LoadResult<T> {
  const _LoadResult({
    this.data,
    this.error,
  });

  final T? data;
  final Object? error;
}
