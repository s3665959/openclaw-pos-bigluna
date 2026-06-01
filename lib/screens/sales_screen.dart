import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late Future<_SalesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SalesData> _load() async {
    final api = AppServices.api;
    final values = await Future.wait<Object?>([
      api.getTodaySalesSummary().catchError((_) => const SalesSummary(
            totalSalesAmount: 0,
            transactionCount: 0,
            averageSaleValue: 0,
            firstSaleTime: '',
            lastSaleTime: '',
          )),
      api.getTodaySales().catchError((_) => <SalesRecord>[]),
      api.getTopProductsToday().catchError((_) => <Map<String, dynamic>>[]),
    ]);
    return _SalesData(
      summary: values[0] as SalesSummary,
      rows: values[1] as List<SalesRecord>,
      topProducts: values[2] as List<Map<String, dynamic>>,
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
      title: 'Sales',
      actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'ยอดขายวันนี้',
              subtitle: 'connector ปัจจุบัน exposed แค่ today sales',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InfoPill(label: 'Historical range ยังไม่พร้อม'),
                  const SizedBox(height: 12),
                  FutureBuilder<_SalesData>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingStateView(message: 'กำลังโหลด sales...');
                      }
                      if (snapshot.hasError) {
                        return ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh);
                      }

                      final data = snapshot.data!;
                      return Column(
                        children: [
                          GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                            childAspectRatio: 1.7,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: [
                              StatCard(label: 'ยอดรวม', value: formatMoney(data.summary.totalSalesAmount), icon: Icons.attach_money_rounded),
                              StatCard(label: 'ธุรกรรม', value: '${data.summary.transactionCount}', icon: Icons.receipt_long_rounded),
                              StatCard(label: 'เฉลี่ย', value: formatMoney(data.summary.averageSaleValue), icon: Icons.analytics_rounded),
                              StatCard(label: 'ช่วงเวลา', value: '${data.summary.firstSaleTime.isEmpty ? '-' : data.summary.firstSaleTime} - ${data.summary.lastSaleTime.isEmpty ? '-' : data.summary.lastSaleTime}', icon: Icons.schedule_rounded),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<_SalesData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: LoadingStateView(message: 'กำลังโหลดรายการขาย...'),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh),
                  );
                }
                final rows = snapshot.data?.rows ?? const <SalesRecord>[];
                final topProducts = snapshot.data?.topProducts ?? const <Map<String, dynamic>>[];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('รายการขายวันนี้', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (rows.isEmpty)
                      const EmptyStateView(
                        title: 'ยังไม่มีรายการขาย',
                        description: 'เมื่อมี invoice ใหม่จาก connector ข้อมูลจะมาแสดงที่นี่',
                      )
                    else
                      for (final sale in rows.take(20)) ...[
                        Card(
                          elevation: 0,
                          child: ListTile(
                            title: Text(sale.invoiceNo?.isNotEmpty == true ? sale.invoiceNo! : sale.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${sale.customer}\n${sale.date.isEmpty ? '-' : sale.date} ${sale.time}'),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatMoney(sale.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text('${sale.items} items'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 12),
                    Text('Top products today', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (topProducts.isEmpty)
                      const EmptyStateView(
                        title: 'ไม่มี top products',
                        description: 'Connector ยังไม่ส่งข้อมูล top products วันนี้',
                      )
                    else
                      for (final row in topProducts.take(10)) ...[
                        Card(
                          elevation: 0,
                          child: ListTile(
                            title: Text(row['Description']?.toString() ?? row['name']?.toString() ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(row['Category']?.toString() ?? row['category']?.toString() ?? ''),
                            trailing: Text(formatMoney((row['total_net_price'] ?? row['revenue'] ?? 0) as num)),
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

class _SalesData {
  const _SalesData({
    required this.summary,
    required this.rows,
    required this.topProducts,
  });

  final SalesSummary summary;
  final List<SalesRecord> rows;
  final List<Map<String, dynamic>> topProducts;
}
