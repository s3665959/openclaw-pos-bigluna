import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../l10n/app_localizations.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/product_actions_sheet.dart';
import 'product_create_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _manualController = TextEditingController();
  final _scannerController = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final _scrollController = ScrollController();
  final _actionsKey = GlobalKey();

  ProductRecord? _product;
  bool _loading = false;
  String? _error;
  String? _message;
  String? _notFoundBarcode;
  String? _emptyTextQuery;
  String? _lastCode;
  DateTime? _lastAcceptedAt;

  @override
  void dispose() {
    _manualController.dispose();
    _scrollController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  bool _looksLikeBarcode(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (RegExp(r'^\d{6,}$').hasMatch(text)) return true;
    if (RegExp(r'^[A-Za-z0-9\-_]{6,}$').hasMatch(text) && !text.contains(' ')) return true;
    return false;
  }

  Future<ProductRecord?> _reloadCurrentProduct(String sourceCode) async {
    final query = sourceCode.trim();
    if (query.isEmpty) return null;
    final api = AppServices.api;
    final barcode = await api.lookupBarcode(query);
    final detail = await api.lookupProductDetail(query);
    if (barcode == null) {
      return detail;
    }
    if (detail == null) {
      return barcode;
    }
    return ProductRecord(
      id: barcode.id.isNotEmpty ? barcode.id : detail.id,
      name: barcode.name.isNotEmpty ? barcode.name : detail.name,
      category: barcode.category.isNotEmpty ? barcode.category : detail.category,
      vendor: barcode.vendor.isNotEmpty ? barcode.vendor : detail.vendor,
      barcode: barcode.barcode.isNotEmpty ? barcode.barcode : detail.barcode,
      price: barcode.price,
      cost: barcode.cost ?? detail.cost,
      effectiveCost: barcode.effectiveCost ?? detail.effectiveCost,
      posExpectedCost: barcode.posExpectedCost ?? detail.posExpectedCost,
      openClawSupplierLastCost: barcode.openClawSupplierLastCost ?? detail.openClawSupplierLastCost,
      reorderLevel: barcode.reorderLevel ?? detail.reorderLevel,
      lowStockThreshold: barcode.lowStockThreshold ?? detail.lowStockThreshold,
      stockQty: barcode.stockQty,
      status: barcode.status.isNotEmpty ? barcode.status : detail.status,
      raw: {
        ...?detail.raw,
        ...?barcode.raw,
      },
    );
  }

  Future<ProductRecord?> _searchProduct(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;
    if (_looksLikeBarcode(clean)) {
      final exact = await _reloadCurrentProduct(clean);
      if (exact != null) return exact;
      final matches = await AppServices.api.searchProducts(clean, limit: 1);
      if (matches.isEmpty) return null;
      final first = matches.first;
      return await _reloadCurrentProduct(first.barcode.isNotEmpty ? first.barcode : first.id) ?? first;
    }
    final detail = await AppServices.api.lookupProductDetail(clean);
    if (detail != null) return detail;
    final matches = await AppServices.api.searchProducts(clean, limit: 1);
    if (matches.isEmpty) return null;
    final first = matches.first;
    return await _reloadCurrentProduct(first.barcode.isNotEmpty ? first.barcode : first.id) ?? first;
  }

  Future<void> _lookup(String rawCode, {bool fromScanner = false}) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    final now = DateTime.now();
    if (fromScanner && _lastCode == code && _lastAcceptedAt != null && now.difference(_lastAcceptedAt!) < const Duration(seconds: 2)) {
      return;
    }

    if (fromScanner) {
      _manualController.text = code;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
      _lastCode = code;
      _lastAcceptedAt = now;
      _notFoundBarcode = null;
      _emptyTextQuery = null;
    });

    try {
      final product = await _searchProduct(code);
      if (!mounted) return;
      final barcodeLike = _looksLikeBarcode(code);
      setState(() {
        _product = product;
        _loading = false;
        _notFoundBarcode = product == null && barcodeLike ? code : null;
        _emptyTextQuery = product == null && !barcodeLike ? code : null;
        _message = product == null ? null : AppLocalizations.of(context).searchResultsLoaded;
      });
      if (product != null) {
        _playScanConfirm();
        _scrollToActions();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _playScanConfirm() {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    } catch (_) {
      // Best effort only.
    }
  }

  void _scrollToActions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _actionsKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        alignment: 0.12,
      );
    });
  }

  Future<void> _openActions(ProductRecord product, ProductActionMode mode) async {
    final changed = await showProductActionsSheet(
      context,
      product,
      initialMode: mode,
      onProductChanged: (updated) {
        if (!mounted) return;
        setState(() {
          _product = updated;
        });
      },
    );
    if (changed == true) {
      final refreshed = await _reloadCurrentProduct(product.barcode.isNotEmpty ? product.barcode : product.id);
      if (!mounted) return;
      if (refreshed != null) {
        setState(() {
          _product = refreshed;
        });
      }
    }
  }

  Future<void> _openCreateProduct(String stockId) async {
    final created = await openProductCreateScreen(context, initialStockId: stockId);
    if (!mounted || created == null) return;
    setState(() {
      _product = created;
      _manualController.text = created.barcode.isNotEmpty ? created.barcode : created.id;
      _notFoundBarcode = null;
      _emptyTextQuery = null;
      _error = null;
      _message = AppLocalizations.of(context).productCreatedSuccessfully;
    });
    _scrollToActions();
  }

  void _clearState() {
    setState(() {
      _product = null;
      _error = null;
      _message = null;
      _notFoundBarcode = null;
      _emptyTextQuery = null;
      _manualController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product = _product;
    final notFoundBarcode = _notFoundBarcode;
    return AppFrame(
      title: l10n.scanBarcode,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: l10n.scanToSearch,
            subtitle: 'Duplicate scans are ignored automatically for a short period.',
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 300,
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final barcode = capture.barcodes.isNotEmpty ? (capture.barcodes.first.rawValue ?? '') : '';
                        if (barcode.isNotEmpty) {
                          unawaited(_lookup(barcode, fromScanner: true));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _manualController,
                  decoration: InputDecoration(
                    labelText: l10n.searchManually,
                    hintText: l10n.enterBarcodeOrProductName,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                  onSubmitted: _lookup,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : () => _lookup(_manualController.text),
                        icon: const Icon(Icons.search_rounded),
                        label: Text(l10n.search),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: l10n.clear,
                      onPressed: _clearState,
                      icon: const Icon(Icons.clear_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) LoadingStateView(message: l10n.loadingProducts),
          if (_error != null) ...[
            ErrorStateView(message: _error!, onRetry: () => _lookup(_manualController.text)),
            const SizedBox(height: 12),
          ],
          if (_message != null && product != null) ...[
            Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          if (product != null)
            SectionCard(
              key: _actionsKey,
              title: product.name,
              subtitle: 'Data from barcode lookup / product detail',
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoPill(label: product.status),
                      InfoPill(label: product.category),
                      InfoPill(label: product.vendor),
                    ],
                  ),
                  const SizedBox(height: 12),
                  KeyValueRow(label: l10n.stockIdBarcode, value: product.id),
                  KeyValueRow(label: 'Barcode', value: product.barcode),
                  KeyValueRow(label: l10n.retailPrice, value: formatMoney(product.price)),
                  KeyValueRow(label: 'On hand', value: formatQuantity(product.stockQty)),
                  KeyValueRow(label: l10n.costPrice, value: product.cost == null ? '-' : formatMoney(product.cost!)),
                  const SizedBox(height: 12),
                  GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.8,
                    children: [
                      FilledButton.icon(
                        onPressed: AppServices.config.demoReadOnly ? null : () => _openActions(product, ProductActionMode.adjust),
                        icon: const Icon(Icons.swap_vert_rounded),
                        label: const Text('Adjust stock'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openActions(product, ProductActionMode.edit),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit product'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openActions(product, ProductActionMode.suppliers),
                        icon: const Icon(Icons.people_alt_rounded),
                        label: const Text('Manage suppliers'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openActions(product, ProductActionMode.expiry),
                        icon: const Icon(Icons.event_busy_rounded),
                        label: const Text('Add expiry lot'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (notFoundBarcode != null)
            EmptyStateView(
              title: l10n.productNotFound,
              description: '${l10n.stockIdBarcode}: $notFoundBarcode',
              actionLabel: l10n.addNewProduct,
              onAction: () => _openCreateProduct(notFoundBarcode),
            )
          else if (_emptyTextQuery != null)
            EmptyStateView(
              title: l10n.noData,
              description: l10n.noProductsFoundDescription,
            )
          else
            EmptyStateView(
              title: l10n.scanBarcode,
              description: 'Once a code is found, the app will query the live API and show the product details immediately.',
            ),
        ],
      ),
    );
  }
}
