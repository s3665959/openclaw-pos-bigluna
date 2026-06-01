import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';
import '../widgets/product_actions_sheet.dart';

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
  String? _message;
  bool _loading = false;
  String? _lastCode;
  DateTime? _lastAcceptedAt;

  @override
  void dispose() {
    _manualController.dispose();
    _scrollController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _lookup(String rawCode, {bool fromScanner = false}) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    final now = DateTime.now();
    if (fromScanner && _lastCode == code && _lastAcceptedAt != null && now.difference(_lastAcceptedAt!) < const Duration(seconds: 2)) {
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
      _lastCode = code;
      _lastAcceptedAt = now;
    });

    try {
      final product = await _reloadCurrentProduct(code);
      if (!mounted) return;
      setState(() {
        _product = product;
        _loading = false;
        _message = product == null ? 'No product found in the connector API' : 'Lookup successful';
      });
      if (product != null) {
        _playScanConfirm();
        _scrollToActions();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = error.toString();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product = _product;
    return AppFrame(
      title: l10n.scanBarcode,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Scan barcode',
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
                const SizedBox(height: 12),
                TextField(
                  controller: _manualController,
                  decoration: const InputDecoration(
                    labelText: 'Enter barcode manually',
                    prefixIcon: Icon(Icons.qr_code_scanner_rounded),
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
                        label: const Text('Search'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        setState(() {
                          _product = null;
                          _message = null;
                          _manualController.clear();
                        });
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const LoadingStateView(message: 'Searching products...'),
          if (_message != null) ...[
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
                  KeyValueRow(label: 'Stock ID', value: product.id),
                  KeyValueRow(label: 'Barcode', value: product.barcode),
                  KeyValueRow(label: 'Price', value: formatMoney(product.price)),
                  KeyValueRow(label: 'On hand', value: formatQuantity(product.stockQty)),
                  KeyValueRow(label: 'Cost', value: product.cost == null ? '-' : formatMoney(product.cost!)),
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
                  if (AppServices.config.demoReadOnly)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Demo Mode: Real data changes are disabled'),
                    ),
                ],
              ),
            )
          else
            const EmptyStateView(
              title: 'Scan or enter a barcode',
              description: 'Once a code is found, the app will query the live API and show the product details immediately.',
            ),
        ],
      ),
    );
  }
}
