import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../l10n/app_localizations.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/product_actions_sheet.dart';
import 'barcode_capture_screen.dart';
import 'product_create_screen.dart';

String _formatProductPriceLine(ProductRecord product) {
  final costText = product.cost == null ? '-' : formatMoney(product.cost!);
  final retailText = formatMoney(product.price);
  return 'Cost: $costText / Retail Price: $retailText';
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late Future<ProductListPage> _future;
  Timer? _searchDebounce;
  String _searchInput = '';
  String _query = '';
  String? _selectedCategory;
  String? _selectedVendor;
  String? _selectedStockStatus;
  String? _pendingCreateBarcode;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  bool _looksLikeBarcode(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (RegExp(r'^\d{6,}$').hasMatch(text)) return true;
    if (RegExp(r'^[A-Za-z0-9\-_]{6,}$').hasMatch(text) && !text.contains(' ')) return true;
    return false;
  }

  Future<ProductListPage> _load() async {
    final page = await AppServices.api.listProducts(
      page: 1,
      limit: 100,
      q: _query,
      category: _selectedCategory,
      vendor: _selectedVendor,
      stockStatus: _selectedStockStatus,
    );
    if (page.rows.isNotEmpty || _query.isEmpty) {
      return page;
    }
    final fallback = await AppServices.api.searchProducts(_query, limit: 100);
    if (fallback.isEmpty) return page;
    return ProductListPage(page: 1, limit: fallback.length, total: fallback.length, totalPages: 1, rows: fallback);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _applySearch() async {
    final query = _searchInput.trim();
    setState(() {
      _query = query;
      _pendingCreateBarcode = _looksLikeBarcode(query) ? query : null;
      _future = _load();
    });
    await _future;
  }

  Future<void> _openActions(ProductRecord product, {ProductActionMode initialMode = ProductActionMode.adjust}) async {
    final changed = await showProductActionsSheet(
      context,
      product,
      initialMode: initialMode,
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _openCreateProduct({String? initialStockId}) async {
    final created = await openProductCreateScreen(context, initialStockId: initialStockId);
    if (!mounted || created == null) return;
    final nextQuery = created.barcode.isNotEmpty ? created.barcode : created.id;
    _searchController.text = nextQuery;
    setState(() {
      _searchInput = nextQuery;
      _query = nextQuery;
      _pendingCreateBarcode = null;
      _future = _load();
    });
    await _future;
    if (!mounted) return;
    await _openActions(created, initialMode: ProductActionMode.edit);
  }

  Future<void> _scanForSearch() async {
    final code = await openBarcodeCaptureScreen(context);
    if (!mounted || code == null || code.trim().isEmpty) return;
    _searchController.text = code;
    setState(() {
      _searchInput = code;
    });
    await _applySearch();
  }

  Widget? _buildSearchSuffix(AppLocalizations l10n) {
    if (_searchController.text.isEmpty) {
      return IconButton(
        tooltip: l10n.scanToSearch,
        onPressed: _scanForSearch,
        icon: const Icon(Icons.qr_code_scanner_rounded),
      );
    }
    return SizedBox(
      width: 96,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.clear,
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchInput = '';
                _query = '';
                _pendingCreateBarcode = null;
                _future = _load();
              });
            },
            icon: const Icon(Icons.clear_rounded),
          ),
          IconButton(
            tooltip: l10n.scanToSearch,
            onPressed: _scanForSearch,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFrame(
      title: l10n.products,
      actions: [
        IconButton(
          tooltip: l10n.refresh,
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
              title: l10n.searchProducts,
              subtitle: 'Supports name / SKU / barcode from the live API',
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: l10n.search,
                      hintText: l10n.searchProductsHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _buildSearchSuffix(l10n),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchInput = value;
                      });
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                        if (!mounted) return;
                        setState(() {
                          _query = _searchInput.trim();
                          _pendingCreateBarcode = _looksLikeBarcode(_query) ? _query : null;
                          _future = _load();
                        });
                      });
                    },
                    onSubmitted: (_) => _applySearch(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedStockStatus,
                          decoration: const InputDecoration(labelText: 'Stock status'),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All')),
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
                          label: Text(l10n.search),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openCreateProduct(),
                      icon: const Icon(Icons.add_box_rounded),
                      label: Text(l10n.addNewProduct),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<ProductListPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: LoadingStateView(message: l10n.loadingProducts),
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
                  if (_pendingCreateBarcode != null && _pendingCreateBarcode!.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: EmptyStateView(
                        title: l10n.productNotFound,
                        description: '${l10n.stockIdBarcode}: ${_pendingCreateBarcode!}',
                        actionLabel: l10n.addNewProduct,
                        onAction: () => _openCreateProduct(initialStockId: _pendingCreateBarcode),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: EmptyStateView(
                      title: l10n.noProducts,
                      description: l10n.noProductsFoundDescription,
                    ),
                  );
                }

                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${page?.total ?? rows.length} items found',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final product in rows) ...[
                      Card(
                        elevation: 0,
                        child: ListTile(
                          onTap: () => _openActions(product),
                          title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${product.barcode}\n${_formatProductPriceLine(product)}\n${product.category}',
                              maxLines: 3,
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
