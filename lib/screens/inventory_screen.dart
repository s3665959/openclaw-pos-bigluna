import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';
import 'operations_screen.dart';

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
      api.getStockSummary().catchError((_) => <String, int>{}),
      api.listProducts(limit: 100, q: _query.isEmpty ? null : _query, stockStatus: stockStatus).catchError((_) => ProductListPage(page: 1, limit: 0, total: 0, totalPages: 1, rows: const [])),
    ]);

    return _InventoryData(
      summary: results[0] as Map<String, int>,
      page: results[1] as ProductListPage,
    );
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
    return AppFrame(
      title: 'Inventory',
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionCard(
              title: 'ภาพรวม stock',
              subtitle: 'ดึงจาก /stock/summary และ /products/list',
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'ค้นหาสินค้าใน inventory',
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
                    decoration: const InputDecoration(labelText: 'ตัวกรอง'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
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
                    child: LoadingStateView(message: 'กำลังโหลด inventory...'),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh),
                  );
                }

                final data = snapshot.data;
                final summary = data?.summary ?? const <String, int>{};
                final page = data?.page;
                final total = summary['totalProducts'] ?? page?.total ?? 0;
                final low = summary['lowStockCount'] ?? 0;
                final out = summary['outOfStockCount'] ?? 0;
                final negative = summary['negativeStockCount'] ?? 0;
                final healthy = (total - low - out - negative).clamp(0, 999999);

                final rows = page?.rows ?? const <ProductRecord>[];
                return Column(
                  children: [
                    GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                      childAspectRatio: 1.5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        StatCard(label: 'Healthy', value: '$healthy', icon: Icons.verified_rounded),
                        StatCard(label: 'Low', value: '$low', icon: Icons.warning_amber_rounded),
                        StatCard(label: 'Out', value: '$out', icon: Icons.remove_circle_outline_rounded),
                        StatCard(label: 'Negative', value: '$negative', icon: Icons.trending_down_rounded),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${rows.length} รายการที่ตรงกับตัวกรอง', style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyStateView(
                          title: 'ไม่มีรายการใน filter นี้',
                          description: 'ลองเปลี่ยนตัวกรองหรือค้นหาใหม่',
                        ),
                      )
                    else
                      for (final product in rows) ...[
                        Card(
                          elevation: 0,
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
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
                            subtitle: Text('${product.id} • ${product.vendor}\n${product.category}'),
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
  });

  final Map<String, int> summary;
  final ProductListPage page;
}
