import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  late Future<List<PurchaseOrderRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = AppServices.api.listPurchaseOrders();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = AppServices.api.listPurchaseOrders();
    });
    await _future;
  }

  Future<void> _openDetail(PurchaseOrderRecord order) async {
    try {
      final data = await AppServices.api.getPurchaseOrder(order.id);
      final receiving = await AppServices.api.getPurchaseOrderReceivingStatus(order.id).catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      final lines = (data['lines'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList(growable: false);
      final summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.84,
            minChildSize: 0.5,
            maxChildSize: 0.96,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Text(order.poNo, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoPill(label: order.status),
                      InfoPill(label: 'Lines: ${order.lineCount ?? lines.length}'),
                      InfoPill(label: 'Receiving: ${receiving['status']?.toString() ?? '-'}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Order summary',
                    child: Column(
                      children: [
                        KeyValueRow(label: 'Supplier', value: order.supplierNameSnapshot),
                        KeyValueRow(label: 'Created by', value: order.createdBy),
                        KeyValueRow(label: 'Created at', value: formatDateTimeText(order.createdAt)),
                        KeyValueRow(label: 'Estimated total', value: formatMoney(order.estimatedTotal ?? 0)),
                        KeyValueRow(label: 'Items count', value: '${order.itemsCount ?? lines.length}'),
                        KeyValueRow(label: 'Receiving received', value: '${receiving['received_qty_total'] ?? '-'}'),
                        KeyValueRow(label: 'Receiving accepted', value: '${receiving['accepted_qty_total'] ?? '-'}'),
                        if ((summary['notes']?.toString() ?? '').isNotEmpty) KeyValueRow(label: 'Summary notes', value: summary['notes'].toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Purchase order lines',
                    child: lines.isEmpty
                        ? const Text('No lines returned by API')
                        : Column(
                            children: [
                              for (final row in lines.take(20))
                                KeyValueRow(
                                  label: row['stock_id']?.toString() ?? '',
                                  value: '${row['product_name_snapshot']?.toString() ?? ''} • x${row['qty']?.toString() ?? ''}',
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: AppServices.config.demoReadOnly
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('ยืนยันการรับสินค้า'),
                                  content: Text('จะบันทึกรับสินค้าทั้งหมดสำหรับ ${order.poNo}'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(false),
                                      child: const Text('ยกเลิก'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(true),
                                      child: const Text('ยืนยัน'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirm != true) return;
                            try {
                              final response = await AppServices.api.saveFullGoodsReceipt(order.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('บันทึกรับสินค้าเรียบร้อย: ${response['receipt']?['receipt_no'] ?? response['receipt']?['receiptNo'] ?? 'สำเร็จ'}'),
                                ),
                              );
                              await _refresh();
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: const Text('รับสินค้าทั้งหมด'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      title: 'Purchase Orders',
      actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionCard(
              title: 'PO list',
              subtitle: 'อ่านจาก /purchase-orders และ /purchase-orders/:id',
              child: Column(
                children: [
                  InfoPill(label: AppServices.config.demoReadOnly ? 'Read-only mode' : 'Write enabled'),
                  const SizedBox(height: 12),
                  FutureBuilder<List<PurchaseOrderRecord>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingStateView(message: 'กำลังโหลด purchase orders...');
                      }
                      if (snapshot.hasError) {
                        return ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh);
                      }
                      final rows = snapshot.data ?? const <PurchaseOrderRecord>[];
                      if (rows.isEmpty) {
                        return const EmptyStateView(
                          title: 'ไม่มี PO',
                          description: 'API ไม่ส่งรายการ PO หรือยังไม่มีข้อมูล',
                        );
                      }
                      return Column(
                        children: [
                          for (final order in rows) ...[
                            Card(
                              elevation: 0,
                              child: ListTile(
                                onTap: () => _openDetail(order),
                                title: Text(order.poNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${order.supplierNameSnapshot}\n${formatDateTimeText(order.createdAt)}'),
                                isThreeLine: true,
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(order.status),
                                    const SizedBox(height: 4),
                                    Text(formatMoney(order.estimatedTotal ?? 0)),
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
          ],
        ),
      ),
    );
  }
}
