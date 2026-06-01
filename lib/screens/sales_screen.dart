import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/formatters.dart';
import '../l10n/app_localizations.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late Future<_SalesData> _future;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SalesData> _load() async {
    final api = AppServices.api;
    if (_isToday(_selectedDate)) {
      final values = await Future.wait<Object?>([
        _loadResult(() => api.getTodaySalesSummary()),
        _loadResult(() => api.getTodaySales()),
        _loadResult(() => api.getTopProductsToday()),
      ]);
      return _SalesData(
        selectedDate: _selectedDate,
        source: SalesDataSource.liveToday,
        summary: values[0] as _LoadResult<SalesSummary>,
        rows: values[1] as _LoadResult<List<SalesRecord>>,
        topProducts: values[2] as _LoadResult<List<Map<String, dynamic>>>,
      );
    }

    final selectedIso = _dateOnly(_selectedDate);
    final monthKey = '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}';
    final archiveRunsResult = await _loadResult(() => api.listArchiveRuns(month: monthKey, page: 1, pageSize: 50));
    if (archiveRunsResult.error != null) {
      return _SalesData(
        selectedDate: _selectedDate,
        source: SalesDataSource.archive,
        summary: _LoadResult<SalesSummary>(error: archiveRunsResult.error),
        rows: _LoadResult<List<SalesRecord>>(error: archiveRunsResult.error),
        topProducts: const _LoadResult<List<Map<String, dynamic>>>(data: <Map<String, dynamic>>[]),
        archiveLabel: 'API error while loading archive runs',
      );
    }
    final runs = archiveRunsResult.data ?? const <Map<String, dynamic>>[];
    final run = runs.cast<Map<String, dynamic>?>().firstWhere(
          (row) => (row?['business_date']?.toString() ?? '') == selectedIso,
          orElse: () => null,
        );
    if (run == null) {
      return _SalesData(
        selectedDate: _selectedDate,
        source: SalesDataSource.archive,
        summary: const _LoadResult<SalesSummary>(data: null, error: null),
        rows: const _LoadResult<List<SalesRecord>>(data: <SalesRecord>[], error: null),
        topProducts: const _LoadResult<List<Map<String, dynamic>>>(data: <Map<String, dynamic>>[], error: null),
        archiveLabel: 'No archived run found for $selectedIso',
      );
    }

    final runId = run['id']?.toString() ?? '';
    final detailResult = await _loadResult(() => api.getArchiveSalesDetail(runId, page: 1, limit: 200, sort: 'transaction_desc'));
    final detail = detailResult.data ?? const <String, dynamic>{};
    final rows = (detail['rows'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => _archiveRowToSalesRecord(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    final summaryMap = detail['summary'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final totalRevenue = _numberFrom(summaryMap['grand_total'] ?? summaryMap['amount_total'] ?? 0);
    final transactionCount = _intFrom(summaryMap['invoice_count'] ?? rows.length);
    final average = transactionCount > 0 ? totalRevenue / transactionCount : 0.0;
    final firstSaleTime = rows.isEmpty ? '' : rows.first.time;
    final lastSaleTime = rows.isEmpty ? '' : rows.last.time;
    return _SalesData(
      selectedDate: _selectedDate,
      source: SalesDataSource.archive,
      summary: _LoadResult(
        data: SalesSummary(
          totalSalesAmount: totalRevenue,
          transactionCount: transactionCount,
          averageSaleValue: average,
          firstSaleTime: firstSaleTime,
          lastSaleTime: lastSaleTime,
        ),
        error: detailResult.error,
      ),
      rows: _LoadResult(data: rows, error: detailResult.error),
      topProducts: const _LoadResult(data: <Map<String, dynamic>>[]),
      archiveLabel: 'Archive run ${run['business_date']?.toString() ?? selectedIso}',
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _future = _load();
    });
    await _future;
  }

  void _backToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _future = _load();
    });
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
              title: 'Sales',
              subtitle: _isToday(_selectedDate) ? 'Live connector data for today' : 'Archive data for a selected business date',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoPill(label: _isToday(_selectedDate) ? 'Today' : _dateOnly(_selectedDate)),
                      FilledButton.tonalIcon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: const Text('Pick date'),
                      ),
                      if (!_isToday(_selectedDate))
                        OutlinedButton.icon(
                          onPressed: _backToToday,
                          icon: const Icon(Icons.today_rounded),
                          label: const Text('Back to today'),
                        ),
                    ],
                  ),
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
                      final rowsResult = data.rows;
                      final rows = rowsResult.data ?? const <SalesRecord>[];
                      final derived = _summarizeSalesRows(rows);
                      final summary = data.summary.data;
                      final archiveMissing = data.archiveLabel?.startsWith('No archived run found') == true;
                      final effectiveSummary = summary != null && (summary.totalSalesAmount > 0 || summary.transactionCount > 0 || summary.averageSaleValue > 0)
                          ? summary
                          : SalesSummary(
                              totalSalesAmount: derived.totalRevenue,
                              transactionCount: derived.transactionCount,
                              averageSaleValue: derived.averageSale,
                              firstSaleTime: derived.firstSaleTime ?? '',
                              lastSaleTime: derived.lastSaleTime ?? '',
                            );
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
                                value: archiveMissing ? 'Not provided' : (rowsResult.error != null || summary == null ? 'API error' : formatMoney(effectiveSummary.totalSalesAmount)),
                                icon: Icons.attach_money_rounded,
                                subtitle: rowsResult.error?.toString() ?? data.summary.error?.toString(),
                              ),
                              StatCard(
                                label: 'Orders',
                                value: archiveMissing ? 'Not provided' : (rowsResult.error != null || summary == null ? 'API error' : '${effectiveSummary.transactionCount}'),
                                icon: Icons.receipt_long_rounded,
                                subtitle: rowsResult.error?.toString() ?? data.summary.error?.toString(),
                              ),
                              StatCard(
                                label: 'Average',
                                value: archiveMissing ? 'Not provided' : (rowsResult.error != null || summary == null ? 'API error' : formatMoney(effectiveSummary.averageSaleValue)),
                                icon: Icons.analytics_rounded,
                                subtitle: rowsResult.error?.toString() ?? data.summary.error?.toString(),
                              ),
                              StatCard(
                                label: 'Time range',
                                value: archiveMissing
                                    ? 'Not provided'
                                    : rowsResult.error != null || summary == null
                                    ? 'API error'
                                    : effectiveSummary.firstSaleTime.isEmpty && effectiveSummary.lastSaleTime.isEmpty
                                        ? 'Not provided'
                                        : '${effectiveSummary.firstSaleTime.isEmpty ? 'Not provided' : effectiveSummary.firstSaleTime} - ${effectiveSummary.lastSaleTime.isEmpty ? 'Not provided' : effectiveSummary.lastSaleTime}',
                                icon: Icons.schedule_rounded,
                                subtitle: rowsResult.error?.toString() ?? data.summary.error?.toString(),
                              ),
                            ],
                          ),
                          if (data.archiveLabel != null) ...[
                            const SizedBox(height: 12),
                            InfoPill(label: data.archiveLabel!),
                          ],
                          if (data.source == SalesDataSource.archive) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Historical sales come from the archive run for the selected business date.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
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
                    Text('Sales list', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (rowsResult?.error != null)
                      ErrorStateView(message: rowsResult!.error.toString(), onRetry: _refresh)
                    else if (rows.isEmpty)
                      const EmptyStateView(
                        title: 'No sales found',
                        description: 'The selected date returned no invoice rows.',
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
                    Text('Top products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (_isToday(_selectedDate))
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
                              trailing: Text(formatMoney(_numberFrom(row['total_net_price'] ?? row['revenue'] ?? 0))),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ]
                    else
                      const EmptyStateView(
                        title: 'Top products are not available',
                        description: 'Archive sales detail does not currently expose top-product aggregates.',
                      ),
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
    required this.selectedDate,
    required this.source,
    required this.summary,
    required this.rows,
    required this.topProducts,
    this.archiveLabel,
  });

  final DateTime selectedDate;
  final SalesDataSource source;
  final _LoadResult<SalesSummary> summary;
  final _LoadResult<List<SalesRecord>> rows;
  final _LoadResult<List<Map<String, dynamic>>> topProducts;
  final String? archiveLabel;
}

class _LoadResult<T> {
  const _LoadResult({
    this.data,
    this.error,
  });

  final T? data;
  final Object? error;
}

enum SalesDataSource { liveToday, archive }

class _SalesDerived {
  const _SalesDerived({
    required this.totalRevenue,
    required this.transactionCount,
    required this.averageSale,
    required this.firstSaleTime,
    required this.lastSaleTime,
  });

  final double totalRevenue;
  final int transactionCount;
  final double averageSale;
  final String? firstSaleTime;
  final String? lastSaleTime;
}

_SalesDerived _summarizeSalesRows(List<SalesRecord> rows) {
  if (rows.isEmpty) {
    return const _SalesDerived(
      totalRevenue: 0.0,
      transactionCount: 0,
      averageSale: 0.0,
      firstSaleTime: null,
      lastSaleTime: null,
    );
  }
  final totalRevenue = rows.fold<double>(0, (sum, sale) => sum + sale.amount);
  final transactionCount = rows.length;
  final averageSale = transactionCount == 0 ? 0.0 : totalRevenue / transactionCount;
  final firstSaleTime = rows.first.time;
  final lastSaleTime = rows.last.time;
  return _SalesDerived(
    totalRevenue: totalRevenue,
    transactionCount: transactionCount,
    averageSale: averageSale,
    firstSaleTime: firstSaleTime.isEmpty ? null : firstSaleTime,
    lastSaleTime: lastSaleTime.isEmpty ? null : lastSaleTime,
  );
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

String _dateOnly(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

double _numberFrom(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0.0;
}

int _intFrom(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.round();
  return int.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
}

SalesRecord _archiveRowToSalesRecord(Map<String, dynamic> row) {
  final invoiceNo = row['invoice_no']?.toString() ?? '';
  final transactionDate = row['transaction_datetime']?.toString() ?? '';
  final time = transactionDate.contains(' ')
      ? transactionDate.split(' ').last.replaceFirst(RegExp(r'\.\d+$'), '').substring(0, 5)
      : '';
  final customer = row['customer_name']?.toString().trim();
  final paymentMethods = row['payment_methods'];
  return SalesRecord(
    id: invoiceNo.isNotEmpty ? invoiceNo : transactionDate,
    date: row['business_date']?.toString() ?? '',
    time: time,
    customer: (customer != null && customer.isNotEmpty) ? customer : 'CASHCUSTOMER',
    amount: _numberFrom(row['total'] ?? row['amount']),
    gst: _numberFrom(row['gst']),
    items: 1,
    channel: paymentMethods is List ? paymentMethods.map((item) => item.toString()).join(', ') : 'archive',
    confirmed: row['pos_status']?.toString() == 'active',
    invoiceNo: invoiceNo.isEmpty ? null : invoiceNo,
    invoiceDate: row['business_date']?.toString(),
    transactionDate: transactionDate,
  );
}
