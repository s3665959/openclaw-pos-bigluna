import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';
import 'operations_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late Future<ProductListPage> _future;
  String _query = '';
  String? _selectedCategory;
  String? _selectedVendor;
  String? _selectedStockStatus;
  bool _detailLoading = false;
  Object? _detailError;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ProductListPage> _load() {
    return AppServices.api.listProducts(
      page: 1,
      limit: 100,
      q: _query,
      category: _selectedCategory,
      vendor: _selectedVendor,
      stockStatus: _selectedStockStatus,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _applySearch() async {
    setState(() {
      _query = _searchController.text.trim();
      _future = _load();
    });
    await _future;
  }

  Future<void> _openDetails(ProductRecord product) async {
    setState(() {
      _detailError = null;
      _detailLoading = true;
    });

    try {
      final detail = await AppServices.api.lookupProductDetail(product.barcode.isNotEmpty ? product.barcode : product.id) ?? product;
      final suppliers = await AppServices.api.getProductSuppliers(detail.id).catchError((_) => <Map<String, dynamic>>[]);
      if (!mounted) return;
      setState(() {
        _detailLoading = false;
        _detailError = null;
      });
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Text(detail.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoPill(label: detail.status),
                      InfoPill(label: detail.category),
                      InfoPill(label: detail.vendor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'รายละเอียดสินค้า',
                    child: Column(
                      children: [
                        KeyValueRow(label: 'Stock ID', value: detail.id),
                        KeyValueRow(label: 'Barcode', value: detail.barcode),
                        KeyValueRow(label: 'ราคา', value: formatMoney(detail.price)),
                        KeyValueRow(label: 'ต้นทุน', value: detail.cost == null ? '-' : formatMoney(detail.cost!)),
                        KeyValueRow(label: 'คงเหลือ', value: formatQuantity(detail.stockQty)),
                        KeyValueRow(label: 'จุดสั่งซื้อ', value: detail.reorderLevel == null ? '-' : formatQuantity(detail.reorderLevel!)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Vendor link',
                    subtitle: 'ข้อมูลจาก /product-suppliers',
                    child: Column(
                      children: [
                        KeyValueRow(label: 'Supplier rows', value: '${suppliers.length}'),
                        if (suppliers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('ไม่มีข้อมูล supplier link จาก API'),
                          ),
                        for (final supplier in suppliers.take(3))
                          KeyValueRow(
                            label: supplier['supplier_name']?.toString() ?? '',
                            value: '${supplier['vendor_code'] ?? ''}${supplier['is_default'] == true ? ' (default)' : ''}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: detail.id.isEmpty || AppServices.config.demoReadOnly
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OperationsScreen(
                                  section: OperationsSection.stockAdjustment,
                                  initialStockId: detail.id,
                                  initialProductName: detail.name,
                                  initialBarcode: detail.barcode,
                                  initialStockQty: detail.stockQty,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.swap_vert_rounded),
                    label: const Text('ปรับสต็อก'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailLoading = false;
        _detailError = error;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      title: 'Products',
      actions: [
        IconButton(
          tooltip: 'รีเฟรช',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'ค้นหาสินค้า',
              subtitle: 'รองรับชื่อ / SKU / barcode ตาม API จริง',
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'ค้นหา',
                      hintText: 'ชื่อสินค้า, SKU หรือ barcode',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _applySearch();
                              },
                              icon: const Icon(Icons.clear_rounded),
                            ),
                    ),
                    onSubmitted: (_) => _applySearch(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedStockStatus,
                          decoration: const InputDecoration(labelText: 'สถานะ stock'),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                            DropdownMenuItem(value: 'in-stock', child: Text('In stock')),
                            DropdownMenuItem(value: 'low-stock', child: Text('Low stock')),
                            DropdownMenuItem(value: 'out-of-stock', child: Text('Out of stock')),
                            DropdownMenuItem(value: 'negative', child: Text('Negative')),
                          ],
                          onChanged: (value) async {
                            setState(() {
                              _selectedStockStatus = value;
                              _future = _load();
                            });
                            await _future;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _applySearch,
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('ค้นหา'),
                        ),
                      ),
                    ],
                  ),
                  if (AppServices.config.demoReadOnly)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('โหมด Demo: ปิดการบันทึกข้อมูลจริง'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<ProductListPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: LoadingStateView(message: 'กำลังดึงรายการสินค้า...'),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh),
                  );
                }

                final page = snapshot.data;
                final rows = page?.rows ?? const <ProductRecord>[];
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyStateView(
                      title: 'ไม่พบสินค้า',
                      description: 'ลองเปลี่ยนคำค้นหรือรีเฟรชข้อมูลอีกครั้ง',
                    ),
                  );
                }

                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'พบ ${page?.total ?? rows.length} รายการ',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final product in rows) ...[
                      Card(
                        elevation: 0,
                        child: ListTile(
                          onTap: () => _openDetails(product),
                          title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${product.barcode} • ${product.vendor}\n${product.category}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
                    if (_detailLoading) const Padding(padding: EdgeInsets.only(top: 8), child: LoadingStateView(message: 'กำลังดึงรายละเอียด...')),
                    if (_detailError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _detailError.toString(),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
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
