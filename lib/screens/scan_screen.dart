import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';
import 'operations_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _manualController = TextEditingController();
  final _scannerController = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  ProductRecord? _product;
  String? _message;
  bool _loading = false;
  String? _lastCode;
  DateTime? _lastAcceptedAt;

  @override
  void dispose() {
    _manualController.dispose();
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
      final api = AppServices.api;
      final product = await api.lookupBarcode(code) ?? await api.lookupProductDetail(code);
      if (!mounted) return;
      setState(() {
        _product = product;
        _loading = false;
        _message = product == null ? 'No product found in the connector API' : 'Lookup successful';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _openAdjustment(ProductRecord product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OperationsScreen(
          section: OperationsSection.stockAdjustment,
          initialStockId: product.id,
          initialProductName: product.name,
          initialBarcode: product.barcode,
          initialStockQty: product.stockQty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product = _product;
    return AppFrame(
      title: l10n.scanBarcode,
      child: ListView(
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
                  FilledButton.icon(
                    onPressed: AppServices.config.demoReadOnly ? null : () => _openAdjustment(product),
                    icon: const Icon(Icons.swap_vert_rounded),
                    label: const Text('Adjust stock from this item'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: AppServices.config.demoReadOnly
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Confirm demo PO creation'),
                                  content: Text('Create a purchase order for ${product.name}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(true),
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirm != true) return;
                            try {
                              final response = await AppServices.api.createPurchaseOrderFromProduct(product);
                              final orders = (response['response'] as Map?)?['orders'] as List<dynamic>? ?? const <dynamic>[];
                              final poNos = orders.whereType<Map>().map((row) => row['po_no']?.toString() ?? row['poNo']?.toString() ?? '').where((value) => value.isNotEmpty).toList(growable: false);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(poNos.isEmpty ? 'Demo PO created successfully' : 'Demo PO created successfully: ${poNos.join(', ')}'),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                    icon: const Icon(Icons.local_shipping_rounded),
                    label: const Text('Create demo PO'),
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
