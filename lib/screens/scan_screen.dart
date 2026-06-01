import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
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
        _message = product == null ? 'ไม่พบสินค้าใน API ของ connector' : 'ค้นหาสำเร็จ';
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
    final product = _product;
    return AppFrame(
      title: 'Scan Barcode',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'สแกนบาร์โค้ด',
            subtitle: 'กันยิงซ้ำอัตโนมัติเมื่อสแกน barcode เดิมในช่วงสั้น ๆ',
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
                    labelText: 'กรอก barcode เอง',
                    prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                  ),
                  onSubmitted: _lookup,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading || AppServices.config.demoReadOnly ? null : () => _lookup(_manualController.text),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('ค้นหา'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'ล้าง',
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
          if (_loading) const LoadingStateView(message: 'กำลังค้นหาสินค้า...'),
          if (_message != null) ...[
            Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          if (product != null)
            SectionCard(
              title: product.name,
              subtitle: 'ข้อมูลจาก barcode lookup / product detail',
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
                  KeyValueRow(label: 'ราคา', value: formatMoney(product.price)),
                  KeyValueRow(label: 'คงเหลือ', value: formatQuantity(product.stockQty)),
                  KeyValueRow(label: 'ต้นทุน', value: product.cost == null ? '-' : formatMoney(product.cost!)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: AppServices.config.demoReadOnly ? null : () => _openAdjustment(product),
                    icon: const Icon(Icons.swap_vert_rounded),
                    label: const Text('ปรับสต็อกจากรายการนี้'),
                  ),
                  if (AppServices.config.demoReadOnly)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('โหมด Demo: ปิดการบันทึกข้อมูลจริง'),
                    ),
                ],
              ),
            )
          else
            const EmptyStateView(
              title: 'รอสแกนหรือกรอก barcode',
              description: 'เมื่ออ่านค่าได้แล้วระบบจะค้นหาสินค้าจาก API จริงและแสดงรายละเอียดทันที',
            ),
        ],
      ),
    );
  }
}
