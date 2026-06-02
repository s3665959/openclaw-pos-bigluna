import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api/app_services.dart';
import '../models/pos_models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';

enum OperationsSection { goodsReceiving, stockAdjustment, expiryLots }

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({
    super.key,
    required this.section,
    this.initialStockId,
    this.initialProductName,
    this.initialBarcode,
    this.initialStockQty,
  });

  final OperationsSection section;
  final String? initialStockId;
  final String? initialProductName;
  final String? initialBarcode;
  final double? initialStockQty;

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  late Future<Object> _future;
  final _operatorController = TextEditingController(text: 'Big Luna Demo');
  final _reasonController = TextEditingController(text: 'Demo from Big Luna POS');
  final _qtyController = TextEditingController(text: '1');
  final _stockIdController = TextEditingController();
  final _productNameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _batchNoController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _notesController = TextEditingController();
  final _alertDaysController = TextEditingController(text: '30');
  final _searchController = TextEditingController();
  String _direction = 'increase';
  String _qtyActionMessage = '';
  String _expiryMessage = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stockIdController.text = widget.initialStockId ?? '';
    _productNameController.text = widget.initialProductName ?? '';
    _barcodeController.text = widget.initialBarcode ?? '';
    _future = _load();
  }

  @override
  void dispose() {
    _operatorController.dispose();
    _reasonController.dispose();
    _qtyController.dispose();
    _stockIdController.dispose();
    _productNameController.dispose();
    _barcodeController.dispose();
    _batchNoController.dispose();
    _expiryDateController.dispose();
    _notesController.dispose();
    _alertDaysController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<Object> _load() async {
    return switch (widget.section) {
      OperationsSection.goodsReceiving => AppServices.api.listGoodsReceipts(),
      OperationsSection.stockAdjustment => AppServices.api.getRecentAdjustments(),
      OperationsSection.expiryLots => _loadExpiryLots(),
    };
  }

  Future<Map<String, dynamic>> _loadExpiryLots() async {
    final summary = await AppServices.api.getExpirySummary();
    final stockId = _searchController.text.trim().isNotEmpty
        ? _searchController.text.trim()
        : (summary.isNotEmpty ? summary.first.stockId : widget.initialStockId ?? '');
    final lots = stockId.isEmpty ? const <ExpiryLotRecord>[] : await AppServices.api.getExpiryLots(stockId);
    return {
      'summary': summary,
      'lots': lots,
      'stockId': stockId,
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _submitAdjustment() async {
    final stockId = _stockIdController.text.trim();
    if (stockId.isEmpty) return;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 1;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm stock adjustment'),
          content: Text('Send ${_direction == 'increase' ? 'increase' : 'decrease'} $qty units for $stockId?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() {
      _busy = true;
      _qtyActionMessage = '';
    });
    try {
      final result = await AppServices.api.directAdjustStock(
        stockId: stockId,
        direction: _direction,
        qty: qty,
        operatorName: _operatorController.text.trim(),
        reason: _reasonController.text.trim(),
        idempotencyKey: 'big-luna-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _qtyActionMessage = 'Saved: ${result.stockTakeNo.isEmpty ? result.id : result.stockTakeNo} | ${result.beforeQty} -> ${result.afterQty}';
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _qtyActionMessage = error.toString();
      });
    }
  }

  Future<void> _submitExpiryLot() async {
    final stockId = _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : _stockIdController.text.trim();
    if (stockId.isEmpty) return;
    if (_productNameController.text.trim().isEmpty || _batchNoController.text.trim().isEmpty || _expiryDateController.text.trim().isEmpty) {
      setState(() {
        _expiryMessage = 'Fill stock id, product, batch, and expiry date.';
      });
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm expiry lot'),
          content: Text('Save an expiry lot for $stockId?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() {
      _busy = true;
      _expiryMessage = '';
    });
    try {
      final result = await AppServices.api.createExpiryLot({
        'stock_id': stockId,
        'product_name_snapshot': _productNameController.text.trim(),
        'batch_no': _batchNoController.text.trim(),
        'expiry_date': _expiryDateController.text.trim(),
        'qty': int.tryParse(_qtyController.text.trim()) ?? 1,
        'alert_days_before': int.tryParse(_alertDaysController.text.trim()) ?? 30,
        'notes': _notesController.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _busy = false;
        _expiryMessage = 'Saved lot ${result.batchNo} (${result.status})';
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _expiryMessage = error.toString();
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final initial = _parseExpiryDate(_expiryDateController.text) ?? DateTime.now();
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
      _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      _expiryMessage = '';
    });
  }

  DateTime? _parseExpiryDate(String value) {
    final parsed = value.trim();
    if (parsed.isEmpty) return null;
    return DateTime.tryParse(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFrame(
      title: switch (widget.section) {
        OperationsSection.goodsReceiving => l10n.goodsReceiving,
        OperationsSection.stockAdjustment => l10n.stockAdjustment,
        OperationsSection.expiryLots => l10n.expiryLots,
      },
      actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (widget.section == OperationsSection.stockAdjustment)
              SectionCard(
                title: 'Stock adjustment',
                subtitle: 'Uses /stock/direct-adjust only',
                child: Column(
                  children: [
                    TextField(
                      controller: _stockIdController,
                      decoration: const InputDecoration(labelText: 'Stock ID', prefixIcon: Icon(Icons.inventory_2_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _productNameController,
                      decoration: const InputDecoration(labelText: 'Product name', prefixIcon: Icon(Icons.label_rounded)),
                    ),
                    const SizedBox(height: 12),
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
                            decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers_rounded)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _operatorController,
                      decoration: const InputDecoration(labelText: 'Operator', prefixIcon: Icon(Icons.badge_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      decoration: const InputDecoration(labelText: 'Reason', prefixIcon: Icon(Icons.edit_note_rounded)),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy || AppServices.config.demoReadOnly ? null : _submitAdjustment,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Submit adjustment'),
                    ),
                    if (_qtyActionMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_qtyActionMessage),
                    ],
                  ],
                ),
              ),
            if (widget.section == OperationsSection.expiryLots)
              SectionCard(
                title: 'Expiry lots',
                subtitle: 'Load summary and create lots via /expiry',
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(labelText: 'Stock ID (optional)', prefixIcon: Icon(Icons.search_rounded)),
                      onSubmitted: (_) => _refresh(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _productNameController,
                      decoration: const InputDecoration(labelText: 'Product name snapshot', prefixIcon: Icon(Icons.label_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _batchNoController,
                      decoration: const InputDecoration(labelText: 'Batch no', prefixIcon: Icon(Icons.qr_code_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _expiryDateController,
                      readOnly: true,
                      onTap: _pickExpiryDate,
                      decoration: InputDecoration(
                        labelText: 'Expiry date (YYYY-MM-DD)',
                        prefixIcon: const Icon(Icons.event_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Pick date',
                          onPressed: _pickExpiryDate,
                          icon: const Icon(Icons.calendar_month_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _alertDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Alert days before', prefixIcon: Icon(Icons.notifications_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes_rounded)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty', prefixIcon: Icon(Icons.scale_rounded)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy || AppServices.config.demoReadOnly ? null : _submitExpiryLot,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Save lot'),
                          ),
                        ),
                      ],
                    ),
                    if (_expiryMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_expiryMessage),
                    ],
                  ],
                ),
              ),
            FutureBuilder<Object>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: LoadingStateView(message: 'Loading data...'),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh),
                  );
                }

                switch (widget.section) {
                  case OperationsSection.goodsReceiving:
                    final rows = snapshot.data as List<GoodsReceiptRecord>;
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Goods receiving list',
                          subtitle: 'Loaded from /goods-receiving',
                          child: rows.isEmpty
                              ? const EmptyStateView(
                                  title: 'No goods receipts',
                                  description: 'The API did not return any receipt rows yet.',
                                )
                              : Column(
                                  children: [
                                    for (final receipt in rows.take(15))
                                      KeyValueRow(
                                        label: receipt.receiptNo,
                                        value: '${receipt.poNo} • ${receipt.status}',
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  case OperationsSection.stockAdjustment:
                    final rows = snapshot.data as List<Map<String, dynamic>>;
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Recent adjustments',
                          subtitle: 'Loaded from /stock/recent-adjustments',
                          child: rows.isEmpty
                              ? const EmptyStateView(
                                  title: 'No recent adjustments',
                                  description: 'When stock changes are posted by the connector, they will appear here.',
                                )
                              : Column(
                                  children: [
                                    for (final row in rows.take(15))
                                      KeyValueRow(
                                        label: row['stockTakeNo']?.toString() ?? row['stock_take_no']?.toString() ?? row['id']?.toString() ?? '-',
                                        value: '${row['productName']?.toString() ?? row['product_name']?.toString() ?? ''} • ${row['afterQty']?.toString() ?? row['after_qty']?.toString() ?? ''}',
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  case OperationsSection.expiryLots:
                    final payload = snapshot.data as Map<String, dynamic>;
                    final summary = (payload['summary'] as List<ExpirySummaryItem>?) ?? const <ExpirySummaryItem>[];
                    final lots = (payload['lots'] as List<ExpiryLotRecord>?) ?? const <ExpiryLotRecord>[];
                    final stockId = payload['stockId']?.toString() ?? '';
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Expiry summary',
                          subtitle: stockId.isEmpty ? 'Choose a stock ID to view lots' : 'Stock: $stockId',
                          child: summary.isEmpty
                              ? const Text('No expiry summary rows returned by API')
                              : Column(
                                  children: [
                                    for (final row in summary.take(10))
                                      KeyValueRow(
                                        label: row.stockId,
                                        value: '${row.productNameSnapshot} • lot ${row.lotCount} • ${row.status}',
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        SectionCard(
                          title: 'Lots',
                          subtitle: 'Loaded from /expiry?stock_id=...',
                          child: lots.isEmpty
                              ? const Text('No lots for this stock')
                              : Column(
                                  children: [
                                    for (final row in lots.take(15))
                                      KeyValueRow(
                                        label: row.batchNo,
                                        value: '${row.expiryDate} • qty ${row.qty} • ${row.status}',
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
