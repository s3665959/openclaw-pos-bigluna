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
  late Future<SalesProfitReport> _future;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SalesProfitReport> _load() {
    return AppServices.api.getSalesProfitReport(_selectedDate);
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
    final isToday = _isToday(_selectedDate);
    return AppFrame(
      title: l10n.sales,
      actions: [
        IconButton(
          tooltip: l10n.refresh,
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<SalesProfitReport>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _ReportHeader(
                    selectedDate: _selectedDate,
                    isToday: isToday,
                    onPickDate: _pickDate,
                    onBackToToday: _backToToday,
                  ),
                  const SizedBox(height: 16),
                  LoadingStateView(message: l10n.loadingSales),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _ReportHeader(
                    selectedDate: _selectedDate,
                    isToday: isToday,
                    onPickDate: _pickDate,
                    onBackToToday: _backToToday,
                  ),
                  const SizedBox(height: 16),
                  ErrorStateView(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  ),
                ],
              );
            }

            final report = snapshot.data!;
            if (!report.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _ReportHeader(
                    selectedDate: _selectedDate,
                    isToday: isToday,
                    onPickDate: _pickDate,
                    onBackToToday: _backToToday,
                  ),
                  const SizedBox(height: 16),
                  EmptyStateView(
                    title: l10n.noSalesData,
                    description: report.message.isNotEmpty ? report.message : l10n.historicalCostBasisNote,
                    actionLabel: l10n.salesReportRetry,
                    onAction: _refresh,
                  ),
                ],
              );
            }

            final summary = report.summary;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _ReportHeader(
                  selectedDate: _selectedDate,
                  isToday: isToday,
                  onPickDate: _pickDate,
                  onBackToToday: _backToToday,
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: l10n.salesProfitReport,
                  subtitle: report.message.isNotEmpty ? report.message : l10n.historicalCostBasisNote,
                  trailing: InfoPill(label: _sourceLabel(context, report.dataSource)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                        mainAxisExtent: 128,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          StatCard(label: l10n.totalSales, value: formatAudMoney(summary.totalSales), icon: Icons.payments_rounded),
                          StatCard(label: l10n.grossProfit, value: formatAudMoney(summary.grossProfit), icon: Icons.trending_up_rounded),
                          StatCard(label: l10n.grossMargin, value: '${summary.grossMarginPercent.toStringAsFixed(2)}%', icon: Icons.percent_rounded),
                          StatCard(label: l10n.orders, value: summary.orderCount.toString(), icon: Icons.receipt_long_rounded),
                          StatCard(label: l10n.itemsSold, value: formatQuantity(summary.itemsSold), icon: Icons.shopping_bag_rounded),
                          StatCard(label: l10n.cogs, value: formatAudMoney(summary.cogs), icon: Icons.inventory_2_rounded),
                          StatCard(label: l10n.averageOrderValue, value: formatAudMoney(summary.averageOrderValue), icon: Icons.analytics_rounded),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          InfoPill(label: '${l10n.selectedBusinessDate}: ${report.date}'),
                          InfoPill(label: 'Cost basis: ${report.costBasis}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SalesProfitSection(
                  title: l10n.topProductsByProfit,
                  rows: report.topByProfit,
                  emptyTitle: l10n.noSalesData,
                  emptyDescription: l10n.noRankedProducts,
                  showMargin: true,
                ),
                const SizedBox(height: 16),
                _SalesProfitSection(
                  title: l10n.topProductsByQuantity,
                  rows: report.topByQuantity,
                  emptyTitle: l10n.noSalesData,
                  emptyDescription: l10n.noQuantityAnalysis,
                  showMargin: false,
                ),
                const SizedBox(height: 16),
                _SalesProfitSection(
                  title: l10n.lowOrNegativeProfitItems,
                  rows: report.negativeOrLowMarginItems,
                  emptyTitle: l10n.noLowMarginItems,
                  emptyDescription: l10n.allAboveMarginThreshold,
                  showMargin: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _sourceLabel(BuildContext context, String value) {
    final l10n = AppLocalizations.of(context);
    switch (value) {
      case 'live_today':
        return l10n.liveToday;
      case 'archive':
        return l10n.archiveSource;
      default:
        return value.isEmpty ? l10n.unknownSource : value;
    }
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.selectedDate,
    required this.isToday,
    required this.onPickDate,
    required this.onBackToToday,
  });

  final DateTime selectedDate;
  final bool isToday;
  final Future<void> Function() onPickDate;
  final VoidCallback onBackToToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: l10n.sales,
      subtitle: l10n.dailyBusinessReview,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          InfoPill(label: isToday ? l10n.today : _dateOnly(selectedDate)),
          FilledButton.tonalIcon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(l10n.pickDate),
          ),
          if (!isToday)
            OutlinedButton.icon(
              onPressed: onBackToToday,
              icon: const Icon(Icons.today_rounded),
              label: Text(l10n.today),
            ),
        ],
      ),
    );
  }
}

class _SalesProfitSection extends StatelessWidget {
  const _SalesProfitSection({
    required this.title,
    required this.rows,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.showMargin,
  });

  final String title;
  final List<SalesProfitProduct> rows;
  final String emptyTitle;
  final String emptyDescription;
  final bool showMargin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: title,
      child: rows.isEmpty
          ? EmptyStateView(title: emptyTitle, description: emptyDescription)
          : Column(
              children: rows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.productName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                row.stockId.isEmpty ? (row.category.isEmpty ? '-' : row.category) : row.stockId,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  InfoPill(label: '${l10n.quantity}: ${formatQuantity(row.quantity)}'),
                                  InfoPill(label: 'Sales: ${formatAudMoney(row.sales)}'),
                                  InfoPill(label: '${l10n.cogs}: ${formatAudMoney(row.cost)}'),
                                  InfoPill(label: '${l10n.grossProfit}: ${formatAudMoney(row.grossProfit)}'),
                                  if (showMargin)
                                    InfoPill(label: '${l10n.margin}: ${row.grossMarginPercent.toStringAsFixed(2)}%'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

String _dateOnly(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
