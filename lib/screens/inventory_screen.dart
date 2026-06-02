import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';
import 'operations_screen.dart';

String _formatProductPriceLine(ProductRecord product) {
  final costText = product.cost == null ? '-' : formatMoney(product.cost!);
  final retailText = formatMoney(product.price);
  return 'Cost: $costText / Retail Price: $retailText';
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  late Future<_InventoryData> _future;
  String _filter = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_InventoryData> _load() async {
    final api = AppServices.api;
    final stockStatus = switch (_filter) {
      'low-stock' => 'low-stock',
      'out-of-stock' => 'out-of-stock',
      'negative' => 'negative',
      'healthy' => 'in-stock',
      _ => null,
    };

    final results = await Future.wait<Object?>([
      _loadResult(() => api.getStockSummary()),
      _loadResult(() => api.listProducts(limit: 100, q: _query.isEmpty ? null : _query, stockStatus: stockStatus)),
      _loadResult(() => api.getProductCount()),
    ]);

    return _InventoryData(
      summary: results[0] as _LoadResult<Map<String, int>>,
      page: results[1] as _LoadResult<ProductListPage>,
      productCount: results[2] as _LoadResult<int>,
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFrame(
      title: l10n.inventory,
      actions: [
        IconButton(tooltip: l10n.refresh, onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionCard(
              title: 'Stock overview',
              subtitle: 'Pulled from /stock/summary and /products/list',
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search inventory products',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: (value) async {
                      setState(() {
                        _query = value.trim();
                        _future = _load();
                      });
                      await _future;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _filter,
                    decoration: const InputDecoration(labelText: 'Filter'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'healthy', child: Text('Healthy stock')),
                      DropdownMenuItem(value: 'low-stock', child: Text('Low stock')),
                      DropdownMenuItem(value: 'out-of-stock', child: Text('Out of stock')),
                      DropdownMenuItem(value: 'negative', child: Text('Negative')),
                    ],
                    onChanged: (value) async {
                      setState(() {
                        _filter = value ?? 'all';
                        _future = _load();
                      });
                      await _future;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<_InventoryData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: LoadingStateView(message: 'Loading inventory...'),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh),
                  );
                }

                final data = snapshot.data;
                final summaryResult = data?.summary;
                final pageResult = data?.page;
                final productCountResult = data?.productCount;
                final summary = summaryResult?.data;
                final page = pageResult?.data;
                final total = summary?['totalProducts'] ?? productCountResult?.data ?? page?.total;
                final low = summary?['lowStockCount'];
                final out = summary?['outOfStockCount'];
                final negative = summary?['negativeStockCount'];
                final rows = page?.rows ?? const <ProductRecord>[];
                final hasError = summaryResult?.error != null || pageResult?.error != null || productCountResult?.error != null;
                return Column(
                  children: [
                    GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                      mainAxisExtent: 132,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        StatCard(
                          label: 'Healthy',
                          value: hasError || total == null || low == null || out == null || negative == null
                              ? 'API error'
                              : '${(total - low - out - negative).clamp(0, 999999)}',
                          icon: Icons.verified_rounded,
                        ),
                        StatCard(
                          label: 'Low',
                          value: low == null ? 'API error' : '$low',
                          icon: Icons.warning_amber_rounded,
                        ),
                        StatCard(
                          label: 'Out',
                          value: out == null ? 'API error' : '$out',
                          icon: Icons.remove_circle_outline_rounded,
                        ),
                        StatCard(
                          label: 'Negative',
                          value: negative == null ? 'API error' : '$negative',
                          icon: Icons.trending_down_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${rows.length} items match the current filter', style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyStateView(
                          title: 'No items in this filter',
                          description: 'Try a different filter or a new search.',
                        ),
                      )
                    else
                      for (final product in rows) ...[
                        Card(
                          elevation: 0,
                          child: ListTile(
                            onTap: AppServices.config.demoReadOnly
                                ? null
                                : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OperationsScreen(
                                  section: OperationsSection.stockAdjustment,
                                  initialStockId: product.id,
                                  initialProductName: product.name,
                                  initialBarcode: product.barcode,
                                  initialStockQty: product.stockQty,
                                ),
                              ),
                            ),
                            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${product.id}\n${_formatProductPriceLine(product)}\n${product.category}'),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatQuantity(product.stockQty), style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                InfoPill(label: product.status),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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

class _InventoryData {
  const _InventoryData({
    required this.summary,
    required this.page,
    required this.productCount,
  });

  final _LoadResult<Map<String, int>> summary;
  final _LoadResult<ProductListPage> page;
  final _LoadResult<int> productCount;
}

class _LoadResult<T> {
  const _LoadResult({
    this.data,
    this.error,
  });

  final T? data;
  final Object? error;
}
