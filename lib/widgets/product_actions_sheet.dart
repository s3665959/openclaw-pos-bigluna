import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../l10n/app_localizations.dart';
import 'common_widgets.dart';

enum ProductActionMode { adjust, edit, suppliers, expiry }

Future<bool?> showProductActionsSheet(
  BuildContext context,
  ProductRecord product, {
  ProductActionMode initialMode = ProductActionMode.adjust,
  ValueChanged<ProductRecord>? onProductChanged,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.65,
      maxChildSize: 0.98,
      builder: (context, controller) => ProductActionsSheet(
        product: product,
        initialMode: initialMode,
        controller: controller,
        onProductChanged: onProductChanged,
      ),
    ),
  );
}

class ProductActionsSheet extends StatefulWidget {
  const ProductActionsSheet({
    super.key,
    required this.product,
    required this.initialMode,
    required this.controller,
    this.onProductChanged,
  });

  final ProductRecord product;
  final ProductActionMode initialMode;
  final ScrollController controller;
  final ValueChanged<ProductRecord>? onProductChanged;

  @override
  State<ProductActionsSheet> createState() => _ProductActionsSheetState();
}

class _ProductActionsSheetState extends State<ProductActionsSheet> {
  late ProductRecord _product;
  late ProductActionMode _mode;

  final _qtyController = TextEditingController(text: '1');
  final _reasonController = TextEditingController(text: 'Demo from Big Luna POS');
  final _operatorController = TextEditingController(text: 'Big Luna Demo');
  final _productNameController = TextEditingController();
  final _costController = TextEditingController();
  final _sellingController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _vendorIdController = TextEditingController();
  final _vendorCodeController = TextEditingController();
  final _vendorContactController = TextEditingController();
  final _vendorSearchController = TextEditingController();
  final _lastCostController = TextEditingController();
  final _priorityController = TextEditingController(text: '0');
  final _supplierNotesController = TextEditingController();
  final _batchController = TextEditingController();
  final _expiryController = TextEditingController();
  final _expiryQtyController = TextEditingController(text: '1');
  final _alertDaysController = TextEditingController(text: '30');
  final _expiryNotesController = TextEditingController();

  String _direction = 'increase';
  bool _loading = false;
  bool _saving = false;
  bool _loadingSuppliers = false;
  bool _loadingExpiry = false;
  String? _message;
  String? _error;
  Map<String, dynamic>? _supplierSummary;
  List<Map<String, dynamic>> _supplierRows = const [];
  List<VendorDirectoryRecord> _vendorResults = const [];
  List<ExpiryLotRecord> _expiryRows = const [];
  String _vendorSearchError = '';
  Timer? _vendorSearchDebounce;
  String? _editingSupplierId;
  String? _editingExpiryId;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _mode = widget.initialMode;
    _productNameController.text = widget.product.name;
    _costController.text = _editableCostText(widget.product);
    _sellingController.text = _editablePriceText(widget.product);
    _loadModeData(_mode);
  }

  @override
  void dispose() {
    _vendorSearchDebounce?.cancel();
    _qtyController.dispose();
    _reasonController.dispose();
    _operatorController.dispose();
    _productNameController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    _supplierNameController.dispose();
    _vendorIdController.dispose();
    _vendorCodeController.dispose();
    _vendorContactController.dispose();
    _vendorSearchController.dispose();
    _lastCostController.dispose();
    _priorityController.dispose();
    _supplierNotesController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    _expiryQtyController.dispose();
    _alertDaysController.dispose();
    _expiryNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadModeData(ProductActionMode mode) async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      switch (mode) {
        case ProductActionMode.adjust:
          break;
        case ProductActionMode.edit:
          final refreshed = await _reloadProduct();
          if (refreshed != null) {
            _product = refreshed;
            _productNameController.text = refreshed.name;
            _costController.text = _editableCostText(refreshed);
            _sellingController.text = _editablePriceText(refreshed);
          }
          break;
        case ProductActionMode.suppliers:
          await _loadSuppliers();
          break;
        case ProductActionMode.expiry:
          await _loadExpiry();
          break;
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<ProductRecord?> _reloadProduct() async {
    final api = AppServices.api;
    final query = _product.barcode.isNotEmpty ? _product.barcode : _product.id;
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

  Future<void> _loadSuppliers() async {
    setState(() {
      _loadingSuppliers = true;
    });
    try {
      final api = AppServices.api;
      _supplierRows = await api.getProductSuppliers(_product.id);
      _supplierSummary = await api.getProductSupplierSummary(_product.id).catchError((_) => <String, dynamic>{});
      final defaultSupplier = _supplierSummary?['defaultSupplierName']?.toString().trim() ?? '';
      _supplierNameController.text = defaultSupplier.isNotEmpty ? defaultSupplier : '';
      _vendorIdController.clear();
      _vendorCodeController.clear();
      _vendorContactController.clear();
      _lastCostController.clear();
      _priorityController.text = '0';
      _supplierNotesController.clear();
      _editingSupplierId = null;
      _vendorResults = const [];
      _vendorSearchError = '';
    } finally {
      if (mounted) {
        setState(() {
          _loadingSuppliers = false;
        });
      }
    }
  }

  Future<void> _loadExpiry() async {
    setState(() {
      _loadingExpiry = true;
    });
    try {
      final api = AppServices.api;
      _expiryRows = await api.getExpiryLots(_product.id);
      _editingExpiryId = null;
      _batchController.text = await api.getNextExpiryBatchNo(_product.id).catchError((_) => '');
      _expiryController.text = '';
      _expiryQtyController.text = '1';
      _alertDaysController.text = '30';
      _expiryNotesController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _loadingExpiry = false;
        });
      }
    }
  }

  void _setMode(ProductActionMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _error = null;
      _message = null;
    });
    unawaited(_loadModeData(mode));
  }

  Future<void> _adjustStock() async {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _error = 'Quantity must be greater than zero.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm stock adjustment'),
          content: Text(
            '${_direction == 'increase' ? 'Increase' : 'Decrease'} ${_product.name} by $qty?\n'
            'Before: ${_product.stockQty}\n'
            'Expected after: ${_direction == 'increase' ? _product.stockQty + qty : _product.stockQty - qty}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirm')),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final result = await AppServices.api.directAdjustStock(
        stockId: _product.id,
        direction: _direction,
        qty: qty,
        operatorName: _operatorController.text.trim(),
        reason: _reasonController.text.trim(),
        idempotencyKey: 'big-luna-${DateTime.now().millisecondsSinceEpoch}',
      );
      final refreshed = await _reloadProduct();
      if (refreshed != null) {
        _product = refreshed;
        widget.onProductChanged?.call(refreshed);
      }
      setState(() {
        _message = 'Saved ${result.stockTakeNo.isEmpty ? result.id : result.stockTakeNo}';
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveProduct() async {
    final productName = _productNameController.text.trim();
    final costPrice = _editableCostValue(_product, _costController.text.trim());
    final sellingPrice = double.tryParse(_sellingController.text.trim());
    if (productName.isEmpty || costPrice == null || costPrice < 0 || sellingPrice == null || sellingPrice < 0) {
      setState(() => _error = 'Enter a valid product name, cost price, and selling price.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm product update'),
          content: Text('Save changes for ${_product.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirm')),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final updated = await AppServices.api.updateProduct(
        stockId: _product.id,
        productName: productName,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
      );
      final refreshed = updated ?? await _reloadProduct();
      if (refreshed != null) {
        _product = refreshed;
        widget.onProductChanged?.call(refreshed);
        _productNameController.text = refreshed.name;
        _costController.text = _editableCostText(refreshed);
        _sellingController.text = _editablePriceText(refreshed);
      }
      setState(() {
        _message = 'Product updated successfully';
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      final errorText = error.toString();
      if (errorText.contains('default_vendor_cost_not_found')) {
        setState(() {
          _error = 'The backend still does not have a default vendor cost row for this product. Save the default supplier record first, then retry product edit.';
        });
        return;
      }
      setState(() {
        _error = errorText;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _editableCostText(ProductRecord product) {
    final cost = _editableCostValue(product, '');
    return cost == null ? '0' : _trimNumeric(cost);
  }

  String _editablePriceText(ProductRecord product) {
    final price = _editablePriceValue(product);
    return _trimNumeric(price);
  }

  double? _editableCostValue(ProductRecord product, String inputText) {
    final parsedInput = _parseNumber(inputText);
    if (parsedInput != null) {
      return parsedInput;
    }
    final raw = product.raw ?? const <String, dynamic>{};
    final candidates = <dynamic>[
      product.cost,
      raw['cost'],
      raw['cost_price'],
      raw['CostPrice'],
      raw['Cost'],
      raw['UnitCost'],
      raw['unit_cost'],
      raw['unitCost'],
    ];
    for (final candidate in candidates) {
      final parsed = _parseNumber(candidate?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double _editablePriceValue(ProductRecord product) {
    final raw = product.raw ?? const <String, dynamic>{};
    final candidates = <dynamic>[
      product.price,
      raw['price'],
      raw['selling_price'],
      raw['sellingPrice'],
      raw['SalesPrice1'],
      raw['SalesPrice'],
      raw['UnitPrice'],
      raw['unit_price'],
    ];
    for (final candidate in candidates) {
      final parsed = _parseNumber(candidate?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return product.price;
  }

  double? _parseNumber(String text) {
    final normalized = text.trim().replaceAll(',', '');
    if (normalized.isEmpty || normalized.toUpperCase() == 'NULL') {
      return null;
    }
    return double.tryParse(normalized);
  }

  String _trimNumeric(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  void _searchVendors(String value) {
    _vendorSearchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _vendorResults = const [];
        _vendorSearchError = '';
      });
      return;
    }
    _vendorSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _vendorSearchError = '';
      });
      try {
        final results = await AppServices.api.searchVendorDirectory(q: query, page: 1, limit: 8);
        if (!mounted) return;
        setState(() {
          _vendorResults = results;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _vendorResults = const [];
          _vendorSearchError = error.toString();
        });
      }
    });
  }

  Future<void> _saveSupplier() async {
    final name = _supplierNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Supplier name is required.');
      return;
    }
    final payload = <String, dynamic>{
      'stock_id': _product.id,
      'supplier_name': name,
      'vendor_contact': _vendorContactController.text.trim(),
      'vendor_code': _vendorCodeController.text.trim(),
      'vendor_id': _vendorIdController.text.trim(),
      'vendor_name_snapshot': name,
      'last_cost': _lastCostController.text.trim().isEmpty ? null : double.tryParse(_lastCostController.text.trim()),
      'is_default': true,
      'priority': int.tryParse(_priorityController.text.trim()) ?? 0,
      'notes': _supplierNotesController.text.trim(),
    };
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm supplier update'),
          content: Text('Save supplier relation for ${_product.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirm')),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      if (_editingSupplierId == null) {
        await AppServices.api.createProductSupplier(payload);
      } else {
        await AppServices.api.updateProductSupplier(_editingSupplierId!, payload);
      }
      await _loadSuppliers();
      setState(() {
        _message = 'Supplier saved successfully';
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editSupplier(Map<String, dynamic> row) async {
    setState(() {
      _editingSupplierId = row['id']?.toString();
      _supplierNameController.text = row['supplierName']?.toString() ?? row['supplier_name']?.toString() ?? '';
      _vendorIdController.text = row['vendorId']?.toString() ?? row['vendor_id']?.toString() ?? '';
      _vendorCodeController.text = row['vendorCode']?.toString() ?? row['vendor_code']?.toString() ?? '';
      _vendorContactController.text = row['vendorContact']?.toString() ?? row['vendor_contact']?.toString() ?? '';
      _lastCostController.text = row['lastCost']?.toString() ?? row['last_cost']?.toString() ?? '';
      _priorityController.text = row['priority']?.toString() ?? '0';
      _supplierNotesController.text = row['notes']?.toString() ?? '';
    });
    _setMode(ProductActionMode.suppliers);
  }

  Future<void> _deleteSupplier(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete supplier relation?'),
          content: const Text('This will remove the supplier relation from the product.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
          ],
        );
      },
    );
    if (confirm != true) return;
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      await AppServices.api.deleteProductSupplier(id);
      await _loadSuppliers();
      setState(() {
        _message = 'Supplier deleted successfully';
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveExpiry() async {
    final batchNo = _batchController.text.trim();
    final expiryDate = _expiryController.text.trim();
    final qty = int.tryParse(_expiryQtyController.text.trim()) ?? 0;
    final alertDays = int.tryParse(_alertDaysController.text.trim()) ?? 0;
    if (batchNo.isEmpty || expiryDate.isEmpty || qty <= 0) {
      setState(() => _error = 'Expiry date and qty are required.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm expiry lot'),
          content: Text('Save an expiry lot for ${_product.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirm')),
          ],
        );
      },
    );
    if (confirm != true) return;
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final payload = <String, dynamic>{
        'stock_id': _product.id,
        'product_name_snapshot': _product.name,
        'batch_no': batchNo,
        'expiry_date': expiryDate,
        'qty': qty,
        'alert_days_before': alertDays,
        'notes': _expiryNotesController.text.trim(),
      };
      if (_editingExpiryId == null) {
        await AppServices.api.createExpiryLot(payload);
      } else {
        await AppServices.api.updateExpiryLot(_editingExpiryId!, payload);
      }
      await _loadExpiry();
      setState(() {
        _message = 'Expiry lot saved successfully';
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editExpiry(ExpiryLotRecord row) async {
    setState(() {
      _editingExpiryId = row.id;
      _batchController.text = row.batchNo;
      _expiryController.text = row.expiryDate;
      _expiryQtyController.text = row.qty.toString();
      _alertDaysController.text = row.alertDaysBefore.toString();
      _expiryNotesController.text = row.notes;
    });
    _setMode(ProductActionMode.expiry);
  }

  Future<void> _pickExpiryDate() async {
    final initial = _parseExpiryDate(_expiryController.text) ?? DateTime.now();
    final firstDate = DateTime(2000);
    final lastDate = DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate)
          ? firstDate
          : initial.isAfter(lastDate)
              ? lastDate
              : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select expiry date',
    );
    if (picked == null) return;
    setState(() {
      _expiryController.text = DateFormat('yyyy-MM-dd').format(picked);
      _error = null;
      _message = null;
    });
  }

  DateTime? _parseExpiryDate(String value) {
    final parsed = value.trim();
    if (parsed.isEmpty) return null;
    return DateTime.tryParse(parsed);
  }

  Future<void> _deleteExpiry(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete expiry lot?'),
          content: const Text('This will remove the expiry lot from the backend.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
          ],
        );
      },
    );
    if (confirm != true) return;
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      await AppServices.api.deleteExpiryLot(id);
      await _loadExpiry();
      setState(() {
        _message = 'Expiry lot deleted successfully';
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ListView(
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_product.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${_product.id} • ${formatQuantity(_product.stockQty)} • ${_product.category}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Adjust stock'),
                  selected: _mode == ProductActionMode.adjust,
                  onSelected: (_) => _setMode(ProductActionMode.adjust),
                ),
                FilterChip(
                  label: const Text('Edit product'),
                  selected: _mode == ProductActionMode.edit,
                  onSelected: (_) => _setMode(ProductActionMode.edit),
                ),
                FilterChip(
                  label: const Text('Manage suppliers'),
                  selected: _mode == ProductActionMode.suppliers,
                  onSelected: (_) => _setMode(ProductActionMode.suppliers),
                ),
                FilterChip(
                  label: const Text('Add expiry lot'),
                  selected: _mode == ProductActionMode.expiry,
                  onSelected: (_) => _setMode(ProductActionMode.expiry),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LoadingStateView(message: 'Loading...'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ErrorStateView(message: _error!, onRetry: () => _loadModeData(_mode)),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  ),
                ),
              ),
            switch (_mode) {
              ProductActionMode.adjust => _buildAdjust(context),
              ProductActionMode.edit => _buildEdit(context),
              ProductActionMode.suppliers => _buildSuppliers(context),
              ProductActionMode.expiry => _buildExpiry(context),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildAdjust(BuildContext context) {
    final before = _product.stockQty;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final expectedAfter = _direction == 'increase' ? before + qty : before - qty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Stock adjustment',
          subtitle: 'Uses /stock/direct-adjust',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _direction,
                      decoration: const InputDecoration(labelText: 'Direction'),
                      items: const [
                        DropdownMenuItem(value: 'increase', child: Text('Increase stock')),
                        DropdownMenuItem(value: 'decrease', child: Text('Decrease stock')),
                      ],
                      onChanged: (value) => setState(() => _direction = value ?? 'increase'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _operatorController,
                decoration: const InputDecoration(labelText: 'Operator'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving || AppServices.config.demoReadOnly ? null : _adjustStock,
                icon: _saving ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Submit adjustment'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Before: ${formatQuantity(before)}  •  Expected after: ${formatQuantity(expectedAfter)}'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEdit(BuildContext context) {
    return SectionCard(
      title: 'Edit product',
      subtitle: 'Uses /products/update',
      child: Column(
        children: [
          TextField(
            controller: _productNameController,
            decoration: const InputDecoration(labelText: 'Product name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _costController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cost price'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sellingController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Selling price'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving || AppServices.config.demoReadOnly ? null : _saveProduct,
            icon: _saving ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'Save product'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliers(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Manage suppliers',
          subtitle: 'Uses /product-suppliers',
          child: Column(
            children: [
              TextField(
                controller: _vendorSearchController,
                decoration: const InputDecoration(labelText: 'Search vendor', hintText: 'Vendor name or code'),
                onChanged: _searchVendors,
              ),
              if (_vendorSearchError.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_vendorSearchError, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (_vendorResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    itemCount: _vendorResults.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final vendor = _vendorResults[index];
                      return ListTile(
                        tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(vendor.vendorName),
                        subtitle: Text('${vendor.vendorId}${vendor.phone.isNotEmpty ? ' • ${vendor.phone}' : ''}'),
                        onTap: () {
                          setState(() {
                            _supplierNameController.text = vendor.vendorName;
                            _vendorIdController.text = vendor.vendorId;
                            _vendorCodeController.text = vendor.vendorCode;
                            _vendorContactController.text = vendor.phone.isNotEmpty ? vendor.phone : vendor.contactName;
                            _vendorSearchController.clear();
                            _vendorResults = const [];
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(controller: _supplierNameController, decoration: const InputDecoration(labelText: 'Supplier name')),
              const SizedBox(height: 12),
              TextField(controller: _vendorIdController, decoration: const InputDecoration(labelText: 'Vendor ID')),
              const SizedBox(height: 12),
              TextField(controller: _vendorCodeController, decoration: const InputDecoration(labelText: 'Vendor code')),
              const SizedBox(height: 12),
              TextField(controller: _vendorContactController, decoration: const InputDecoration(labelText: 'Vendor contact')),
              const SizedBox(height: 12),
              TextField(controller: _lastCostController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Last cost')),
              const SizedBox(height: 12),
              TextField(controller: _priorityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Priority')),
              const SizedBox(height: 12),
              TextField(controller: _supplierNotesController, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving || AppServices.config.demoReadOnly ? null : _saveSupplier,
                icon: _saving ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : _editingSupplierId == null ? 'Add supplier' : 'Save supplier'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Current suppliers',
          subtitle: _loadingSuppliers ? 'Loading...' : '${_supplierRows.length} row(s)',
          child: _loadingSuppliers
              ? const LoadingStateView(message: 'Loading suppliers...')
              : _supplierRows.isEmpty
                  ? const EmptyStateView(
                      title: 'No suppliers linked yet',
                      description: 'Add a supplier relation for this product.',
                    )
                  : Column(
                      children: [
                        for (final row in _supplierRows)
                          Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row['supplier_name']?.toString() ?? row['supplierName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('Vendor: ${row['vendor_name_snapshot']?.toString() ?? row['vendorNameSnapshot']?.toString() ?? ''}'),
                                  Text('Code: ${row['vendor_code']?.toString() ?? row['vendorCode']?.toString() ?? ''}'),
                                  Text('Default: ${row['is_default'] == true || row['isDefault'] == true ? 'Yes' : 'No'}'),
                                  Text('Priority: ${row['priority']?.toString() ?? '0'}'),
                                  if ((row['notes']?.toString() ?? '').isNotEmpty) Text('Notes: ${row['notes']}'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton(onPressed: _saving ? null : () => _editSupplier(row), child: const Text('Edit')),
                                      OutlinedButton(onPressed: _saving ? null : () => _deleteSupplier(row['id']?.toString() ?? ''), child: const Text('Delete')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildExpiry(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Add expiry lot',
          subtitle: 'Uses /expiry',
          child: Column(
            children: [
              TextField(controller: _batchController, decoration: const InputDecoration(labelText: 'Batch no')),
              const SizedBox(height: 12),
              TextField(
                controller: _expiryController,
                readOnly: true,
                onTap: _pickExpiryDate,
                decoration: InputDecoration(
                  labelText: 'Expiry date (YYYY-MM-DD)',
                  suffixIcon: IconButton(
                    tooltip: 'Pick date',
                    onPressed: _pickExpiryDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _expiryQtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty')),
              const SizedBox(height: 12),
              TextField(controller: _alertDaysController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Alert days before expiry')),
              const SizedBox(height: 12),
              TextField(controller: _expiryNotesController, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving || AppServices.config.demoReadOnly ? null : _saveExpiry,
                icon: _saving ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : _editingExpiryId == null ? 'Add lot' : 'Save lot'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Existing lots',
          subtitle: _loadingExpiry ? 'Loading...' : '${_expiryRows.length} lot(s)',
          child: _loadingExpiry
              ? const LoadingStateView(message: 'Loading expiry lots...')
              : _expiryRows.isEmpty
                  ? const EmptyStateView(
                      title: 'No expiry lots saved yet',
                      description: 'Add the first expiry lot for this product.',
                    )
                  : Column(
                      children: [
                        for (final lot in _expiryRows)
                          Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lot.batchNo.isNotEmpty ? lot.batchNo : 'No batch', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('Expiry: ${lot.expiryDate}'),
                                  Text('Qty: ${lot.qty} • Alert ${lot.alertDaysBefore} days'),
                                  if (lot.notes.isNotEmpty) Text('Notes: ${lot.notes}'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton(onPressed: _saving ? null : () => _editExpiry(lot), child: const Text('Edit')),
                                      OutlinedButton(onPressed: _saving ? null : () => _deleteExpiry(lot.id), child: const Text('Delete')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}
