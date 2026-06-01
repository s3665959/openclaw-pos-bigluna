class ConnectorHealth {
  const ConnectorHealth({
    required this.ok,
    required this.service,
    required this.mode,
    required this.writeMode,
    this.message,
    this.databaseName,
    this.edition,
  });

  final bool ok;
  final String service;
  final String mode;
  final bool writeMode;
  final String? message;
  final String? databaseName;
  final String? edition;

  factory ConnectorHealth.fromJson(Map<String, dynamic> json, {String? databaseName, String? edition}) {
    return ConnectorHealth(
      ok: _bool(json['ok'], fallback: false),
      service: _text(json['service'], fallback: 'pos-connector'),
      mode: _text(json['mode'], fallback: 'unknown'),
      writeMode: _bool(json['writeMode'], fallback: true),
      message: _text(json['message']).isEmpty ? null : _text(json['message']),
      databaseName: databaseName,
      edition: edition,
    );
  }
}

class DatabaseInfo {
  const DatabaseInfo({
    required this.databaseName,
    this.edition,
  });

  final String databaseName;
  final String? edition;

  factory DatabaseInfo.fromJson(Map<String, dynamic> json) {
    return DatabaseInfo(
      databaseName: _text(json['database_name'], fallback: 'MainDB'),
      edition: _text(json['edition']).isEmpty ? null : _text(json['edition']),
    );
  }
}

class ProductRecord {
  const ProductRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.vendor,
    required this.barcode,
    required this.price,
    required this.stockQty,
    required this.status,
    this.cost,
    this.reorderLevel,
    this.lowStockThreshold,
    this.raw,
  });

  final String id;
  final String name;
  final String category;
  final String vendor;
  final String barcode;
  final double price;
  final double? cost;
  final double? reorderLevel;
  final double? lowStockThreshold;
  final double stockQty;
  final String status;
  final Map<String, dynamic>? raw;

  factory ProductRecord.fromJson(Map<String, dynamic> json) {
    final stockQty = _number(
      json['stockQty'] ?? json['StockQty0001'] ?? json['stock_qty'] ?? json['quantity'] ?? json['qty'],
      fallback: 0,
    );
    final status = _text(json['status']).isNotEmpty
        ? _text(json['status'])
        : stockQty < 0
            ? 'negative'
            : stockQty == 0
                ? 'out-of-stock'
                : stockQty <= 5
                    ? 'low-stock'
                    : 'in-stock';
    final costValue = _numberNullable(
      json['cost'] ?? json['cost_price'] ?? json['CostPrice'] ?? json['Cost'] ?? json['UnitCost'] ?? json['unit_cost'],
    );
    final reorder = _numberNullable(
      json['reorderLevel'] ?? json['reorder_level'] ?? json['reorder'] ?? json['lowStockThreshold'] ?? json['low_stock_threshold'] ?? json['minimum_stock'] ?? json['min_stock'],
    );

    return ProductRecord(
      id: _text(json['id'] ?? json['StockId'] ?? json['stock_id'] ?? json['product_id'], fallback: 'unknown-product'),
      name: _text(json['name'] ?? json['Description'] ?? json['Description1'] ?? json['product_name'], fallback: 'Unknown product'),
      category: _text(json['category'] ?? json['Category'], fallback: 'Unknown'),
      vendor: _text(json['vendor'] ?? json['Vendor'] ?? json['Supplier'], fallback: 'Unknown'),
      barcode: _text(json['barcode'] ?? json['Barcode'] ?? json['Barcode1'] ?? json['Barcode2'] ?? json['StockId'], fallback: ''),
      price: _number(json['price'] ?? json['SalesPrice1'] ?? json['unit_price'] ?? json['UnitPrice'], fallback: 0),
      cost: costValue,
      reorderLevel: reorder,
      lowStockThreshold: reorder,
      stockQty: stockQty,
      status: status,
      raw: json,
    );
  }
}

class ProductListPage {
  const ProductListPage({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.rows,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final List<ProductRecord> rows;

  factory ProductListPage.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => ProductRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    return ProductListPage(
      page: _int(json['page'], fallback: 1),
      limit: _int(json['limit'], fallback: 20),
      total: _int(json['total'], fallback: rows.length),
      totalPages: _int(json['total_pages'] ?? json['totalPages'], fallback: 1),
      rows: rows,
    );
  }
}

class SalesRecord {
  const SalesRecord({
    required this.id,
    required this.date,
    required this.time,
    required this.customer,
    required this.amount,
    required this.gst,
    required this.items,
    required this.channel,
    this.paidAmount,
    this.workStationId,
    this.locationCode,
    this.confirmed,
    this.invoiceNo,
    this.invoiceDate,
    this.transactionDate,
  });

  final String id;
  final String date;
  final String time;
  final String customer;
  final double amount;
  final double gst;
  final int items;
  final String channel;
  final double? paidAmount;
  final String? workStationId;
  final String? locationCode;
  final bool? confirmed;
  final String? invoiceNo;
  final String? invoiceDate;
  final String? transactionDate;

  factory SalesRecord.fromJson(Map<String, dynamic> json) {
    final invoiceNo = _text(json['invoiceNo'] ?? json['InvoiceNo']);
    final transactionDate = _text(json['transactionDate'] ?? json['TransactionDate']);
    final invoiceDate = _text(json['invoiceDate'] ?? json['InvoiceDate']);
    final customer = _text(json['customer'] ?? json['CustomerId'], fallback: 'CASHCUSTOMER');
    final date = invoiceDate.isNotEmpty
        ? invoiceDate.substring(0, invoiceDate.length > 10 ? 10 : invoiceDate.length)
        : transactionDate.isNotEmpty
            ? transactionDate.substring(0, transactionDate.length > 10 ? 10 : transactionDate.length)
            : '';
    final time = _inferHour(transactionDate.isNotEmpty ? transactionDate : invoiceDate);
    return SalesRecord(
      id: _text(json['id'], fallback: invoiceNo.isNotEmpty ? invoiceNo : date.isNotEmpty ? date : customer),
      date: date,
      time: time,
      customer: customer,
      amount: _number(json['amount'] ?? json['Amount'], fallback: 0),
      gst: _number(json['gst'] ?? json['GST'], fallback: 0),
      items: _int(json['items'], fallback: 1),
      channel: _text(json['channel'], fallback: 'in-store'),
      paidAmount: _numberNullable(json['paidAmount'] ?? json['PaidAmount']),
      workStationId: _optionalText(json['workStationId'] ?? json['WorkStationId']),
      locationCode: _optionalText(json['locationCode'] ?? json['LocationCode']),
      confirmed: json['confirmed'] == null ? null : _bool(json['confirmed']),
      invoiceNo: invoiceNo.isEmpty ? null : invoiceNo,
      invoiceDate: invoiceDate.isEmpty ? null : invoiceDate,
      transactionDate: transactionDate.isEmpty ? null : transactionDate,
    );
  }
}

class SalesSummary {
  const SalesSummary({
    required this.totalSalesAmount,
    required this.transactionCount,
    required this.averageSaleValue,
    required this.firstSaleTime,
    required this.lastSaleTime,
  });

  final double totalSalesAmount;
  final int transactionCount;
  final double averageSaleValue;
  final String firstSaleTime;
  final String lastSaleTime;

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    return SalesSummary(
      totalSalesAmount: _number(json['total_sales_amount'] ?? json['totalSalesAmount'], fallback: 0),
      transactionCount: _int(json['transaction_count'] ?? json['transactionCount'], fallback: 0),
      averageSaleValue: _number(json['average_sale_value'] ?? json['averageSaleValue'], fallback: 0),
      firstSaleTime: _text(json['first_sale_time'] ?? json['firstSaleTime']),
      lastSaleTime: _text(json['last_sale_time'] ?? json['lastSaleTime']),
    );
  }
}

class VendorDirectoryRecord {
  const VendorDirectoryRecord({
    required this.vendorId,
    required this.vendorCode,
    required this.vendorName,
    required this.companyName,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.address,
    required this.taxId,
    required this.status,
    required this.productCount,
    required this.defaultProductCount,
    required this.lastPurchaseDate,
    required this.notes,
  });

  final String vendorId;
  final String vendorCode;
  final String vendorName;
  final String companyName;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final String taxId;
  final String status;
  final int productCount;
  final int defaultProductCount;
  final String? lastPurchaseDate;
  final String notes;

  factory VendorDirectoryRecord.fromJson(Map<String, dynamic> json) {
    return VendorDirectoryRecord(
      vendorId: _text(json['vendor_id'] ?? json['vendorId'], fallback: ''),
      vendorCode: _text(json['vendor_code'] ?? json['vendorCode'], fallback: ''),
      vendorName: _text(json['vendor_name'] ?? json['vendorName'] ?? json['name'], fallback: 'Unknown vendor'),
      companyName: _text(json['company_name'] ?? json['companyName'], fallback: ''),
      contactName: _text(json['contact_name'] ?? json['contactName'], fallback: ''),
      phone: _text(json['phone'], fallback: ''),
      email: _text(json['email'], fallback: ''),
      address: _text(json['address'], fallback: ''),
      taxId: _text(json['tax_id'] ?? json['taxId'], fallback: ''),
      status: _text(json['status'], fallback: 'active'),
      productCount: _int(json['product_count'] ?? json['productCount'], fallback: 0),
      defaultProductCount: _int(json['default_product_count'] ?? json['defaultProductCount'], fallback: 0),
      lastPurchaseDate: _optionalText(json['last_purchase_date'] ?? json['lastPurchaseDate']),
      notes: _text(json['notes'], fallback: ''),
    );
  }
}

class VendorProductLink {
  const VendorProductLink({
    required this.stockId,
    required this.productName,
    required this.lastCost,
    required this.priority,
    required this.isDefault,
    required this.notes,
    required this.productUrl,
    required this.vendorId,
    required this.vendorName,
  });

  final String stockId;
  final String productName;
  final double? lastCost;
  final int priority;
  final bool isDefault;
  final String notes;
  final String productUrl;
  final String vendorId;
  final String vendorName;

  factory VendorProductLink.fromJson(Map<String, dynamic> json) {
    return VendorProductLink(
      stockId: _text(json['stock_id'] ?? json['stockId'], fallback: ''),
      productName: _text(json['product_name'] ?? json['productName'], fallback: ''),
      lastCost: _numberNullable(json['last_cost'] ?? json['lastCost']),
      priority: _int(json['priority'], fallback: 0),
      isDefault: _bool(json['is_default'] ?? json['isDefault'], fallback: false),
      notes: _text(json['notes'], fallback: ''),
      productUrl: _text(json['product_url'] ?? json['productUrl'], fallback: ''),
      vendorId: _text(json['vendor_id'] ?? json['vendorId'], fallback: ''),
      vendorName: _text(json['vendor_name'] ?? json['vendorName'], fallback: ''),
    );
  }
}

class PurchaseOrderRecord {
  const PurchaseOrderRecord({
    required this.id,
    required this.poNo,
    required this.supplierId,
    required this.supplierNameSnapshot,
    required this.status,
    required this.sourceDraftId,
    required this.createdBy,
    required this.notes,
    required this.pdfPath,
    required this.createdAt,
    required this.updatedAt,
    this.itemsCount,
    this.estimatedTotal,
    this.lineCount,
  });

  final String id;
  final String poNo;
  final String supplierId;
  final String supplierNameSnapshot;
  final String status;
  final String sourceDraftId;
  final String createdBy;
  final String notes;
  final String? pdfPath;
  final String createdAt;
  final String updatedAt;
  final int? itemsCount;
  final double? estimatedTotal;
  final int? lineCount;

  factory PurchaseOrderRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderRecord(
      id: _text(json['id'], fallback: ''),
      poNo: _text(json['po_no'] ?? json['poNo'], fallback: ''),
      supplierId: _text(json['supplier_id'] ?? json['supplierId'], fallback: ''),
      supplierNameSnapshot: _text(json['supplier_name_snapshot'] ?? json['supplierNameSnapshot'], fallback: ''),
      status: _text(json['status'], fallback: 'unknown'),
      sourceDraftId: _text(json['source_draft_id'] ?? json['sourceDraftId'], fallback: ''),
      createdBy: _text(json['created_by'] ?? json['createdBy'], fallback: ''),
      notes: _text(json['notes'], fallback: ''),
      pdfPath: _optionalText(json['pdf_path'] ?? json['pdfPath']),
      createdAt: _text(json['created_at'] ?? json['createdAt'], fallback: ''),
      updatedAt: _text(json['updated_at'] ?? json['updatedAt'], fallback: ''),
      itemsCount: _intNullable(json['items_count'] ?? json['itemsCount']),
      estimatedTotal: _numberNullable(json['estimated_total'] ?? json['estimatedTotal']),
      lineCount: _intNullable(json['line_count'] ?? json['lineCount']),
    );
  }
}

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.id,
    required this.purchaseOrderId,
    required this.stockId,
    required this.productNameSnapshot,
    required this.qty,
    required this.unitCost,
    required this.lineTotal,
    required this.notes,
  });

  final String id;
  final String purchaseOrderId;
  final String stockId;
  final String productNameSnapshot;
  final int qty;
  final double? unitCost;
  final double? lineTotal;
  final String notes;

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderLine(
      id: _text(json['id'], fallback: ''),
      purchaseOrderId: _text(json['purchase_order_id'] ?? json['purchaseOrderId'], fallback: ''),
      stockId: _text(json['stock_id'] ?? json['stockId'], fallback: ''),
      productNameSnapshot: _text(json['product_name_snapshot'] ?? json['productNameSnapshot'], fallback: ''),
      qty: _int(json['qty'], fallback: 0),
      unitCost: _numberNullable(json['unit_cost'] ?? json['unitCost']),
      lineTotal: _numberNullable(json['line_total'] ?? json['lineTotal']),
      notes: _text(json['notes'], fallback: ''),
    );
  }
}

class GoodsReceiptRecord {
  const GoodsReceiptRecord({
    required this.id,
    required this.receiptNo,
    required this.purchaseOrderId,
    required this.poNo,
    required this.supplierId,
    required this.supplierNameSnapshot,
    required this.status,
    required this.receivedBy,
    required this.receivedAt,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.lineCount,
    this.orderedQtyTotal,
    this.receivedQtyTotal,
    this.damagedQtyTotal,
    this.acceptedQtyTotal,
  });

  final String id;
  final String receiptNo;
  final String purchaseOrderId;
  final String poNo;
  final String supplierId;
  final String supplierNameSnapshot;
  final String status;
  final String receivedBy;
  final String receivedAt;
  final String notes;
  final String createdAt;
  final String updatedAt;
  final int? lineCount;
  final int? orderedQtyTotal;
  final int? receivedQtyTotal;
  final int? damagedQtyTotal;
  final int? acceptedQtyTotal;

  factory GoodsReceiptRecord.fromJson(Map<String, dynamic> json) {
    return GoodsReceiptRecord(
      id: _text(json['id'], fallback: ''),
      receiptNo: _text(json['receipt_no'] ?? json['receiptNo'], fallback: ''),
      purchaseOrderId: _text(json['purchase_order_id'] ?? json['purchaseOrderId'], fallback: ''),
      poNo: _text(json['po_no'] ?? json['poNo'], fallback: ''),
      supplierId: _text(json['supplier_id'] ?? json['supplierId'], fallback: ''),
      supplierNameSnapshot: _text(json['supplier_name_snapshot'] ?? json['supplierNameSnapshot'], fallback: ''),
      status: _text(json['status'], fallback: 'unknown'),
      receivedBy: _text(json['received_by'] ?? json['receivedBy'], fallback: ''),
      receivedAt: _text(json['received_at'] ?? json['receivedAt'], fallback: ''),
      notes: _text(json['notes'], fallback: ''),
      createdAt: _text(json['created_at'] ?? json['createdAt'], fallback: ''),
      updatedAt: _text(json['updated_at'] ?? json['updatedAt'], fallback: ''),
      lineCount: _intNullable(json['line_count'] ?? json['lineCount']),
      orderedQtyTotal: _intNullable(json['ordered_qty_total'] ?? json['orderedQtyTotal']),
      receivedQtyTotal: _intNullable(json['received_qty_total'] ?? json['receivedQtyTotal']),
      damagedQtyTotal: _intNullable(json['damaged_qty_total'] ?? json['damagedQtyTotal']),
      acceptedQtyTotal: _intNullable(json['accepted_qty_total'] ?? json['acceptedQtyTotal']),
    );
  }
}

class GoodsReceiptLine {
  const GoodsReceiptLine({
    required this.id,
    required this.receiptId,
    required this.purchaseOrderLineId,
    required this.stockId,
    required this.productNameSnapshot,
    required this.orderedQty,
    required this.receivedQty,
    required this.damagedQty,
    required this.acceptedQty,
    required this.unitCost,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String receiptId;
  final String purchaseOrderLineId;
  final String stockId;
  final String productNameSnapshot;
  final int orderedQty;
  final int receivedQty;
  final int damagedQty;
  final int acceptedQty;
  final double? unitCost;
  final String notes;
  final String createdAt;
  final String updatedAt;

  factory GoodsReceiptLine.fromJson(Map<String, dynamic> json) {
    return GoodsReceiptLine(
      id: _text(json['id'], fallback: ''),
      receiptId: _text(json['receipt_id'] ?? json['receiptId'], fallback: ''),
      purchaseOrderLineId: _text(json['purchase_order_line_id'] ?? json['purchaseOrderLineId'], fallback: ''),
      stockId: _text(json['stock_id'] ?? json['stockId'], fallback: ''),
      productNameSnapshot: _text(json['product_name_snapshot'] ?? json['productNameSnapshot'], fallback: ''),
      orderedQty: _int(json['ordered_qty'] ?? json['orderedQty'], fallback: 0),
      receivedQty: _int(json['received_qty'] ?? json['receivedQty'], fallback: 0),
      damagedQty: _int(json['damaged_qty'] ?? json['damagedQty'], fallback: 0),
      acceptedQty: _int(json['accepted_qty'] ?? json['acceptedQty'], fallback: 0),
      unitCost: _numberNullable(json['unit_cost'] ?? json['unitCost']),
      notes: _text(json['notes'], fallback: ''),
      createdAt: _text(json['created_at'] ?? json['createdAt'], fallback: ''),
      updatedAt: _text(json['updated_at'] ?? json['updatedAt'], fallback: ''),
    );
  }
}

class ExpirySummaryItem {
  const ExpirySummaryItem({
    required this.stockId,
    required this.productNameSnapshot,
    required this.nextExpiryDate,
    required this.lotCount,
    required this.totalQty,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.status,
  });

  final String stockId;
  final String productNameSnapshot;
  final String? nextExpiryDate;
  final int lotCount;
  final int totalQty;
  final int expiredCount;
  final int expiringSoonCount;
  final String status;

  factory ExpirySummaryItem.fromJson(Map<String, dynamic> json) {
    final nextExpiryDate = _optionalText(json['next_expiry_date'] ?? json['nextExpiryDate']);
    return ExpirySummaryItem(
      stockId: _text(json['stock_id'] ?? json['stockId'], fallback: ''),
      productNameSnapshot: _text(json['product_name_snapshot'] ?? json['productNameSnapshot'], fallback: ''),
      nextExpiryDate: nextExpiryDate,
      lotCount: _int(json['lot_count'] ?? json['lotCount'], fallback: 0),
      totalQty: _int(json['total_qty'] ?? json['totalQty'], fallback: 0),
      expiredCount: _int(json['expired_count'] ?? json['expiredCount'], fallback: 0),
      expiringSoonCount: _int(json['expiring_soon_count'] ?? json['expiringSoonCount'], fallback: 0),
      status: _text(json['status'], fallback: 'no-expiry-data'),
    );
  }
}

class ExpiryLotRecord {
  const ExpiryLotRecord({
    required this.id,
    required this.stockId,
    required this.productNameSnapshot,
    required this.batchNo,
    required this.expiryDate,
    required this.qty,
    required this.alertDaysBefore,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String stockId;
  final String productNameSnapshot;
  final String batchNo;
  final String expiryDate;
  final int qty;
  final int alertDaysBefore;
  final String notes;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory ExpiryLotRecord.fromJson(Map<String, dynamic> json) {
    return ExpiryLotRecord(
      id: _text(json['id'], fallback: ''),
      stockId: _text(json['stock_id'] ?? json['stockId'], fallback: ''),
      productNameSnapshot: _text(json['product_name_snapshot'] ?? json['productNameSnapshot'], fallback: ''),
      batchNo: _text(json['batch_no'] ?? json['batchNo'], fallback: ''),
      expiryDate: _text(json['expiry_date'] ?? json['expiryDate'], fallback: ''),
      qty: _int(json['qty'], fallback: 0),
      alertDaysBefore: _int(json['alert_days_before'] ?? json['alertDaysBefore'], fallback: 30),
      notes: _text(json['notes'], fallback: ''),
      status: _text(json['status'], fallback: 'normal'),
      createdAt: _text(json['created_at'] ?? json['createdAt'], fallback: ''),
      updatedAt: _text(json['updated_at'] ?? json['updatedAt'], fallback: ''),
    );
  }
}

class StockAdjustmentResult {
  const StockAdjustmentResult({
    required this.id,
    required this.stockId,
    required this.productName,
    required this.direction,
    required this.qty,
    required this.delta,
    required this.beforeQty,
    required this.expectedAfterQty,
    required this.afterQty,
    required this.operator,
    required this.reason,
    required this.stockTakeNo,
    required this.idempotencyKey,
    required this.barcode,
    required this.createdAt,
  });

  final String id;
  final String stockId;
  final String productName;
  final String direction;
  final int qty;
  final int delta;
  final int beforeQty;
  final int expectedAfterQty;
  final int afterQty;
  final String operator;
  final String reason;
  final String stockTakeNo;
  final String idempotencyKey;
  final String barcode;
  final String createdAt;

  factory StockAdjustmentResult.fromJson(Map<String, dynamic> json) {
    final direction = _text(json['direction'] ?? json['action'], fallback: 'increase');
    final qty = _int(json['qty'] ?? json['quantity'], fallback: 1);
    final delta = _int(json['delta'] ?? json['adjustment_qty'] ?? json['adjustmentQty'], fallback: qty) * (direction == 'decrease' ? -1 : 1);
    final beforeQty = _int(json['beforeQty'] ?? json['before_qty'] ?? json['currentStock'], fallback: 0);
    final expectedAfterQty = _int(json['expectedAfterQty'] ?? json['expected_after_qty'], fallback: beforeQty + delta);
    final afterQty = _int(json['afterQty'] ?? json['after_qty'], fallback: expectedAfterQty);
    return StockAdjustmentResult(
      id: _text(json['id'] ?? json['adjustmentId'], fallback: 'TX-${DateTime.now().millisecondsSinceEpoch}'),
      stockId: _text(json['stock_id'] ?? json['stockId'] ?? json['StockId'], fallback: ''),
      productName: _text(json['product_name'] ?? json['productName'] ?? json['Description'], fallback: 'Unknown product'),
      direction: direction,
      qty: qty,
      delta: delta,
      beforeQty: beforeQty,
      expectedAfterQty: expectedAfterQty,
      afterQty: afterQty,
      operator: _text(json['operator'] ?? json['operator_name'], fallback: 'mobile-scanner'),
      reason: _text(json['reason'], fallback: 'Mobile scanner adjustment'),
      stockTakeNo: _text(json['stock_take_no'] ?? json['stockTakeNo'] ?? json['document_no'] ?? json['documentNo'], fallback: ''),
      idempotencyKey: _text(json['idempotency_key'] ?? json['idempotencyKey'], fallback: ''),
      barcode: _text(json['barcode'] ?? json['Barcode'] ?? json['StockId'], fallback: ''),
      createdAt: _text(json['createdAt'] ?? json['created_at'], fallback: DateTime.now().toIso8601String()),
    );
  }
}

class SystemSnapshot {
  const SystemSnapshot({
    required this.health,
    required this.databaseInfo,
  });

  final ConnectorHealth? health;
  final DatabaseInfo? databaseInfo;
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toUpperCase() == 'NULL' || text.toLowerCase() == 'null') {
    return fallback;
  }
  return text;
}

String? _optionalText(dynamic value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

double _number(dynamic value, {double fallback = 0}) {
  final text = value?.toString().replaceAll(',', '').trim() ?? '';
  if (text.isEmpty || text.toUpperCase() == 'NULL' || text.toLowerCase() == 'null') {
    return fallback;
  }
  final parsed = double.tryParse(text);
  return parsed ?? fallback;
}

double? _numberNullable(dynamic value) {
  final text = value?.toString().replaceAll(',', '').trim() ?? '';
  if (text.isEmpty || text.toUpperCase() == 'NULL' || text.toLowerCase() == 'null') {
    return null;
  }
  return double.tryParse(text);
}

int _int(dynamic value, {int fallback = 0}) {
  final number = _number(value, fallback: fallback.toDouble());
  return number.isFinite ? number.round() : fallback;
}

int? _intNullable(dynamic value) {
  final number = _numberNullable(value);
  return number?.round();
}

bool _bool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final text = value.toString().trim().toLowerCase();
  if (text.isEmpty) return fallback;
  return text == 'true' || text == '1' || text == 'yes' || text == 'y' || text == 'ok';
}

String _inferHour(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '00';
  final match = RegExp(r'\b(\d{2}):(\d{2})').firstMatch(text);
  if (match != null) {
    return match.group(1) ?? '00';
  }
  final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  if (parsed == null) return '00';
  return parsed.hour.toString().padLeft(2, '0');
}
