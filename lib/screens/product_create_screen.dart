import 'package:flutter/material.dart';

import '../core/api/app_services.dart';
import '../core/api/openclaw_api.dart';
import '../core/formatters.dart';
import '../l10n/app_localizations.dart';
import '../models/pos_models.dart';
import '../widgets/common_widgets.dart';

Future<ProductRecord?> openProductCreateScreen(
  BuildContext context, {
  String? initialStockId,
}) {
  return Navigator.of(context).push<ProductRecord>(
    MaterialPageRoute<ProductRecord>(
      builder: (_) => ProductCreateScreen(initialStockId: initialStockId),
      fullscreenDialog: true,
    ),
  );
}

class ProductCreateScreen extends StatefulWidget {
  const ProductCreateScreen({
    super.key,
    this.initialStockId,
  });

  final String? initialStockId;

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

class _ProductCreateScreenState extends State<ProductCreateScreen> {
  late final TextEditingController _stockIdController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '0');
  final TextEditingController _categoryController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stockIdController = TextEditingController(text: widget.initialStockId?.trim() ?? '');
  }

  @override
  void dispose() {
    _stockIdController.dispose();
    _nameController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final stockId = _stockIdController.text.trim();
    final productName = _nameController.text.trim();
    final costPrice = double.tryParse(_costController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final quantity = int.tryParse(_quantityController.text.trim().isEmpty ? '0' : _quantityController.text.trim()) ?? 0;
    final category = _categoryController.text.trim();
    if (stockId.isEmpty || productName.isEmpty || costPrice == null || costPrice < 0 || price == null || price < 0 || quantity < 0) {
      setState(() {
        _error = 'Please enter valid product details.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await AppServices.api.createProduct(
        stockId: stockId,
        productName: productName,
        costPrice: costPrice,
        sellingPrice: price,
        quantity: quantity,
        category: category.isEmpty ? null : category,
      );
      final product = result.product ??
          await AppServices.api.lookupProductDetail(stockId) ??
          await AppServices.api.lookupBarcode(stockId);
      if (!mounted) return;
      final message = result.initialStockApplied
          ? l10n.productCreatedSuccessfully
          : '${l10n.productCreatedSuccessfully}. Initial stock still needs adjustment.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(product);
    } on ApiException catch (error) {
      if (!mounted) return;
      final payload = error.payload is Map ? Map<String, dynamic>.from(error.payload as Map) : <String, dynamic>{};
      if (error.statusCode == 409) {
        final existingJson = payload['existingProduct'] ?? payload['existing_product'];
        final existingProduct = existingJson is Map ? ProductRecord.fromJson(Map<String, dynamic>.from(existingJson)) : null;
        final openExisting = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.thisBarcodeAlreadyExists),
            content: Text(payload['message']?.toString().trim().isNotEmpty == true ? payload['message'].toString() : l10n.thisBarcodeAlreadyExists),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.openExistingProduct),
              ),
            ],
          ),
        );
        if (openExisting == true && existingProduct != null && mounted) {
          Navigator.of(context).pop(existingProduct);
          return;
        }
      }
      setState(() {
        _error = error.message;
      });
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
    return AppFrame(
      title: l10n.addNewProduct,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: l10n.addNewProduct,
            subtitle: widget.initialStockId == null ? l10n.searchProductsHint : '${l10n.stockIdBarcode}: ${widget.initialStockId}',
            child: Column(
              children: [
                TextField(
                  controller: _stockIdController,
                  decoration: InputDecoration(
                    labelText: l10n.stockIdBarcode,
                    prefixIcon: const Icon(Icons.qr_code_2_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.productName,
                    prefixIcon: const Icon(Icons.inventory_2_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.costPrice,
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.retailPrice,
                    prefixIcon: const Icon(Icons.sell_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.quantity,
                    helperText: l10n.quantityOptionalDefaultsZero,
                    prefixIcon: const Icon(Icons.layers_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: l10n.category,
                    prefixIcon: const Icon(Icons.category_rounded),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_box_rounded),
                    label: Text(_saving ? l10n.loading : l10n.createProduct),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: l10n.productCreatedSuccessfully,
            subtitle: 'Cost updates POS expected cost and quantity uses the existing stock adjustment workflow.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.costPrice}: ${formatMoney(double.tryParse(_costController.text.trim()) ?? 0)}'),
                const SizedBox(height: 8),
                Text('${l10n.retailPrice}: ${formatMoney(double.tryParse(_priceController.text.trim()) ?? 0)}'),
                const SizedBox(height: 8),
                Text('${l10n.quantity}: ${_quantityController.text.trim().isEmpty ? '0' : _quantityController.text.trim()}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
