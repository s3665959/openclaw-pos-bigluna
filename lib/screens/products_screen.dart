import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/product_actions_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _future = _load();
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
    setState(() {
      _query = _searchInput.trim();
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
          tooltip: 'Refresh',
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
              title: 'Search products',
              subtitle: 'Supports name / SKU / barcode from the live API',
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Product name, SKU, or barcode',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchInput = '';
                                });
                                _applySearch();
                              },
                              icon: const Icon(Icons.clear_rounded),
                            ),
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
                          label: const Text('Search'),
                        ),
                      ),
                    ],
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
                    child: LoadingStateView(message: 'Loading products...'),
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
                      title: 'No products found',
                      description: 'Try a different search term or refresh the data.',
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
