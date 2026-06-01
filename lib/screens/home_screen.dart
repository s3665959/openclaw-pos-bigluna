import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';
import 'inventory_screen.dart';
import 'products_screen.dart';
import 'purchase_orders_screen.dart';
import 'sales_screen.dart';
import 'scan_screen.dart';
import 'status_screen.dart';
import 'vendors_screen.dart';
import 'operations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeSnapshot> _load() async {
    final api = AppServices.api;
    final results = await Future.wait<Object?>([
      api.getSystemSnapshot().catchError((_) => const SystemSnapshot(health: null, databaseInfo: null)),
      api.getProductCount().catchError((_) => 0),
      api.getTodaySalesSummary().catchError((_) => const SalesSummary(
            totalSalesAmount: 0,
            transactionCount: 0,
            averageSaleValue: 0,
            firstSaleTime: '',
            lastSaleTime: '',
          )),
    ]);
    return _HomeSnapshot(
      systemSnapshot: results[0] as SystemSnapshot,
      productCount: results[1] as int,
      salesSummary: results[2] as SalesSummary,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      title: 'Big Luna POS',
      actions: [
        IconButton(
          tooltip: 'สถานะระบบ',
          icon: const Icon(Icons.monitor_heart_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatusScreen())),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_HomeSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 120),
                  LoadingStateView(message: 'กำลังโหลด Big Luna POS...'),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  ErrorStateView(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  ),
                ],
              );
            }

            final data = snapshot.data;
            final health = data?.systemSnapshot.health;
            final db = data?.systemSnapshot.databaseInfo;
            final writeMode = health?.writeMode ?? false;
            final statusLabel = health == null
                ? 'ยังไม่ทราบสถานะ'
                : health.ok
                    ? (writeMode ? 'Online / Write enabled' : 'Online / Read only')
                    : 'Offline';
            final statusColor = health == null
                ? Theme.of(context).colorScheme.outline
                : health.ok
                    ? (writeMode ? Colors.green : Colors.orange)
                    : Colors.red;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                SectionCard(
                  title: 'ภาพรวมระบบ',
                  subtitle: 'เชื่อมกับ OpenClaw backend/API จริงผ่าน .env',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          InfoPill(label: statusLabel, color: statusColor),
                          InfoPill(label: db?.databaseName ?? 'DB: ไม่ทราบ'),
                          InfoPill(label: 'Mode: ${health?.mode ?? '-'}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
                        childAspectRatio: 1.85,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          StatCard(
                            label: 'สินค้า',
                            value: '${data?.productCount ?? 0}',
                            icon: Icons.inventory_2_rounded,
                            subtitle: 'รายการจาก /products/count',
                          ),
                          StatCard(
                            label: 'ยอดขายวันนี้',
                            value: formatMoney(data?.salesSummary.totalSalesAmount ?? 0),
                            icon: Icons.receipt_long_rounded,
                            subtitle: '${data?.salesSummary.transactionCount ?? 0} ใบ',
                          ),
                          StatCard(
                            label: 'ฐานข้อมูล',
                            value: db?.databaseName ?? '-',
                            icon: Icons.storage_rounded,
                            subtitle: db?.edition ?? 'ยังไม่ทราบ edition',
                          ),
                          StatCard(
                            label: 'สิทธิ์เขียน',
                            value: writeMode ? 'Enabled' : 'Read only',
                            icon: writeMode ? Icons.edit_note_rounded : Icons.lock_rounded,
                            subtitle: health?.service ?? 'pos-connector',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('เมนู Demo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                FeatureTile(
                  title: 'Products',
                  subtitle: 'ค้นหา/ดูรายละเอียดสินค้าและสต็อกจริง',
                  icon: Icons.inventory_2_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductsScreen())),
                ),
                FeatureTile(
                  title: 'Scan Barcode',
                  subtitle: 'เปิดกล้องสแกนบาร์โค้ดแล้วค้นหาสินค้า',
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
                ),
                FeatureTile(
                  title: 'Inventory',
                  subtitle: 'ดู stock low / out / negative และค้นหาได้',
                  icon: Icons.warehouse_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryScreen())),
                ),
                FeatureTile(
                  title: 'Sales',
                  subtitle: 'ยอดขายวันนี้และรายการขายที่ backend มีจริง',
                  icon: Icons.point_of_sale_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesScreen())),
                ),
                FeatureTile(
                  title: 'Vendors',
                  subtitle: 'รายชื่อ vendor และรายละเอียดจาก API จริง',
                  icon: Icons.people_alt_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VendorsScreen())),
                ),
                FeatureTile(
                  title: 'Purchase Orders',
                  subtitle: 'รายการ PO และรายละเอียดการรับสินค้า',
                  icon: Icons.receipt_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen())),
                ),
                FeatureTile(
                  title: 'Goods Receiving',
                  subtitle: 'ดูรายการใบรับสินค้า / สถานะรับสินค้า',
                  icon: Icons.local_shipping_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OperationsScreen(section: OperationsSection.goodsReceiving))),
                ),
                FeatureTile(
                  title: 'Stock Adjustment',
                  subtitle: 'ปรับสต็อกแบบยืนยันก่อนส่ง API',
                  icon: Icons.swap_vert_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OperationsScreen(section: OperationsSection.stockAdjustment))),
                ),
                FeatureTile(
                  title: 'Expiry Lots',
                  subtitle: 'ดูและเพิ่ม lot วันหมดอายุที่ backend รองรับ',
                  icon: Icons.event_busy_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OperationsScreen(section: OperationsSection.expiryLots))),
                ),
                FeatureTile(
                  title: 'System Status',
                  subtitle: 'สถานะ backend, connector และฐานข้อมูล',
                  icon: Icons.monitor_heart_rounded,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatusScreen())),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeSnapshot {
  const _HomeSnapshot({
    required this.systemSnapshot,
    required this.productCount,
    required this.salesSummary,
  });

  final SystemSnapshot systemSnapshot;
  final int productCount;
  final SalesSummary salesSummary;
}
