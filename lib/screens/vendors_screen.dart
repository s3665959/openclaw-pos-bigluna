import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../models/pos_models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  final _searchController = TextEditingController();
  late Future<_VendorData> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_VendorData> _load() async {
    final api = AppServices.api;
    Map<String, dynamic> summary = <String, dynamic>{};
    List<dynamic> vendors = <dynamic>[];
    try {
      summary = await api.getVendorSummary();
    } catch (_) {
      summary = <String, dynamic>{};
    }
    try {
      vendors = await api.searchVendorDirectory(q: _query, page: 1, limit: 50);
    } catch (_) {
      vendors = <dynamic>[];
    }
    return _VendorData(
      summary: summary,
      vendors: vendors,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openVendor(String vendorId) async {
    final api = AppServices.api;
    try {
      Map<String, dynamic> detail = <String, dynamic>{};
      List<VendorProductLink> products = <VendorProductLink>[];
      try {
        detail = await api.getVendorDetail(vendorId);
      } catch (_) {
        detail = <String, dynamic>{};
      }
      try {
        products = await api.getVendorProducts(vendorId);
      } catch (_) {
        products = <VendorProductLink>[];
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          final vendor = (detail['vendor'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.96,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Text(vendor['vendor_name']?.toString() ?? 'Vendor', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoPill(label: vendor['status']?.toString() ?? '-'),
                      InfoPill(label: '${products.length} linked products'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Vendor detail',
                    child: Column(
                      children: [
                        KeyValueRow(label: 'Vendor ID', value: vendor['vendor_id']?.toString() ?? ''),
                        KeyValueRow(label: 'Code', value: vendor['vendor_code']?.toString() ?? ''),
                        KeyValueRow(label: 'Company', value: vendor['company_name']?.toString() ?? ''),
                        KeyValueRow(label: 'Contact', value: vendor['contact_name']?.toString() ?? ''),
                        KeyValueRow(label: 'Phone', value: vendor['phone']?.toString() ?? ''),
                        KeyValueRow(label: 'Email', value: vendor['email']?.toString() ?? ''),
                        KeyValueRow(label: 'Last purchase', value: vendor['last_purchase_date']?.toString() ?? ''),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Linked products',
                    child: products.isEmpty
                        ? const Text('No linked product rows from API')
                        : Column(
                            children: [
                              for (final row in products.take(10))
                                KeyValueRow(
                                label: row.stockId,
                                value: '${row.productName}${row.isDefault ? ' (default)' : ''}',
                              ),
                          ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Recent purchase orders',
                    child: (detail['recent_purchase_orders'] as List?)?.isEmpty ?? true
                        ? const Text('No recent purchase orders from API')
                        : Column(
                            children: [
                              for (final row in (detail['recent_purchase_orders'] as List).take(5))
                                KeyValueRow(
                                  label: row['po_no']?.toString() ?? '',
                                  value: row['status']?.toString() ?? '',
                                ),
                            ],
                          ),
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFrame(
      title: l10n.vendors,
      actions: [IconButton(tooltip: l10n.refresh, onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionCard(
              title: 'Search vendors',
              subtitle: 'Uses /vendors/search and /vendors/summary',
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Vendor name or code',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: (value) async {
                      setState(() {
                        _query = value.trim();
                        _future = _load();
                      });
                      await _future;
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      setState(() {
                        _query = _searchController.text.trim();
                        _future = _load();
                      });
                      await _future;
                    },
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<_VendorData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: LoadingStateView(message: 'Loading vendors...'),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ErrorStateView(message: snapshot.error.toString(), onRetry: _refresh),
                  );
                }

                final summary = snapshot.data?.summary ?? const <String, dynamic>{};
                final vendors = snapshot.data?.vendors ?? const <dynamic>[];
                final typedVendors = vendors.whereType<dynamic>().toList();
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
                        StatCard(label: 'Total', value: '${summary['total_vendors'] ?? vendors.length}', icon: Icons.people_alt_rounded),
                        StatCard(label: 'With products', value: '${summary['vendors_with_products'] ?? 0}', icon: Icons.link_rounded),
                        StatCard(label: 'Without links', value: '${summary['vendors_missing_product_links'] ?? 0}', icon: Icons.link_off_rounded),
                        StatCard(label: 'Linked products', value: '${summary['linked_product_count'] ?? 0}', icon: Icons.inventory_2_rounded),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (vendors.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyStateView(
                          title: 'No vendors found',
                          description: 'Try a different search term or refresh the data.',
                        ),
                      )
                    else
                      for (final vendor in typedVendors) ...[
                        Card(
                          elevation: 0,
                          child: ListTile(
                            onTap: () => _openVendor((vendor as dynamic).vendorId as String),
                            title: Text((vendor as dynamic).vendorName as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${(vendor as dynamic).contactName as String}\n${(vendor as dynamic).companyName as String}'),
                            isThreeLine: true,
                            trailing: Text('${(vendor as dynamic).productCount as int} products'),
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

class _VendorData {
  const _VendorData({
    required this.summary,
    required this.vendors,
  });

  final Map<String, dynamic> summary;
  final List<dynamic> vendors;
}
