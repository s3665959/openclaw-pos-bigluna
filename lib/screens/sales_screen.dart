import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../models/pos_models.dart';
import '../l10n/app_localizations.dart';
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
      _loadResult(() => api.getTodaySalesSummary()),
      _loadResult(() => api.getTodaySales()),
      _loadResult(() => api.getTopProductsToday()),
    ]);
    return _SalesData(
      summary: values[0] as _LoadResult<SalesSummary>,
      rows: values[1] as _LoadResult<List<SalesRecord>>,
      topProducts: values[2] as _LoadResult<List<Map<String, dynamic>>>,
    );
  }

  Future<_LoadResult<T>> _loadResult<T>(Future<T> Function() loader) async {
    try {
      return _LoadResult<T>(data: await loader());
    } catch (error) {
      return _LoadResult<T>(error: error);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFrame(
      title: l10n.sales,
      actions: [IconButton(tooltip: l10n.refresh, onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Today sales',
              subtitle: 'The current connector only exposes today sales',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InfoPill(label: 'Historical range not available yet'),
                  const SizedBox(height: 12),
                  FutureBuilder<_SalesData>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingStateView(message: 'Loading sales...');
                      }
                      if (snapshot.hasError) {
                        return ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh);
                      }

                      final data = snapshot.data!;
                      final summary = data.summary.data;
                      return Column(
                        children: [
                          GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                            mainAxisExtent: 132,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: [
                              StatCard(
                                label: 'Total',
                                value: summary == null ? 'API error' : formatMoney(summary.totalSalesAmount),
                                icon: Icons.attach_money_rounded,
                                subtitle: data.summary.error?.toString(),
                              ),
                              StatCard(
                                label: 'Orders',
                                value: summary == null ? 'API error' : '${summary.transactionCount}',
                                icon: Icons.receipt_long_rounded,
                                subtitle: data.summary.error?.toString(),
                              ),
                              StatCard(
                                label: 'Average',
                                value: summary == null ? 'API error' : formatMoney(summary.averageSaleValue),
                                icon: Icons.analytics_rounded,
                                subtitle: data.summary.error?.toString(),
                              ),
                              StatCard(
                                label: 'Time range',
                                value: summary == null
                                    ? 'API error'
                                    : '${summary.firstSaleTime.isEmpty ? 'Not provided' : summary.firstSaleTime} - ${summary.lastSaleTime.isEmpty ? 'Not provided' : summary.lastSaleTime}',
                                icon: Icons.schedule_rounded,
                                subtitle: data.summary.error?.toString(),
                              ),
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
                    child: LoadingStateView(message: 'Loading sales list...'),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh),
                  );
                }
                final rowsResult = snapshot.data?.rows;
                final topProductsResult = snapshot.data?.topProducts;
                final rows = rowsResult?.data ?? const <SalesRecord>[];
                final topProducts = topProductsResult?.data ?? const <Map<String, dynamic>>[];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today sales list', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (rowsResult?.error != null)
                      ErrorStateView(message: rowsResult!.error.toString(), onRetry: _refresh)
                    else if (rows.isEmpty)
                      const EmptyStateView(
                        title: 'No sales yet',
                        description: 'When new invoices arrive from the connector, they will appear here.',
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
                    if (topProductsResult?.error != null)
                      ErrorStateView(message: topProductsResult!.error.toString(), onRetry: _refresh)
                    else if (topProducts.isEmpty)
                      const EmptyStateView(
                        title: 'No top products',
                        description: 'The connector has not sent top products data for today yet.',
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

  final _LoadResult<SalesSummary> summary;
  final _LoadResult<List<SalesRecord>> rows;
  final _LoadResult<List<Map<String, dynamic>>> topProducts;
}

class _LoadResult<T> {
  const _LoadResult({
    this.data,
    this.error,
  });

  final T? data;
  final Object? error;
}
