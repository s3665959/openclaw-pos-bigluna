import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../../models/pos_models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.payload});

  final String message;
  final int? statusCode;
  final Object? payload;

  @override
  String toString() => message;
}

class OpenClawApi {
  OpenClawApi({AppConfig? config}) {
    final effectiveConfig = config ?? AppConfig.fromEnv();
    _config = effectiveConfig;
    final headers = <String, dynamic>{'accept': 'application/json'};
    if (effectiveConfig.apiToken.isNotEmpty) {
      headers['authorization'] = effectiveConfig.apiToken.toLowerCase().startsWith('bearer ')
          ? effectiveConfig.apiToken
          : 'Bearer ${effectiveConfig.apiToken}';
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: effectiveConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: headers,
        responseType: ResponseType.json,
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('[OpenClaw API] ${options.method} ${options.uri.path}');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint('[OpenClaw API] <- ${response.statusCode} ${response.requestOptions.uri.path}');
            handler.next(response);
          },
          onError: (error, handler) {
            debugPrint('[OpenClaw API] !! ${error.requestOptions.uri.path} ${error.response?.statusCode ?? ''}');
            handler.next(error);
          },
        ),
      );
  }

  late final Dio _dio;
  late final AppConfig _config;

  bool get isDemoReadOnly => _config.demoReadOnly;

  Future<Map<String, dynamic>> _getMap(String path, {Map<String, dynamic>? query}) async {
    final response = await _request(path, method: 'GET', query: query);
    return _asMap(response.data);
  }

  Future<List<Map<String, dynamic>>> _getRows(String path, {Map<String, dynamic>? query}) async {
    final json = await _getMap(path, query: query);
    final rows = json['rows'];
    if (rows is List) {
      return rows
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    final data = json['data'];
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Response<dynamic>> _request(
    String path, {
    required String method,
    Map<String, dynamic>? query,
    Object? data,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, validateStatus: (_) => true),
      );
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw ApiException(
          _extractMessage(response.data, fallback: 'Request failed (${response.statusCode ?? 'unknown'})'),
          statusCode: response.statusCode,
          payload: response.data,
        );
      }
      return response;
    } on DioException catch (error) {
      throw ApiException(
        _extractMessage(error.response?.data, fallback: error.message ?? 'Network request failed'),
        statusCode: error.response?.statusCode,
        payload: error.response?.data,
      );
    }
  }

  ConnectorHealth _healthFromJson(Map<String, dynamic> json, {DatabaseInfo? databaseInfo}) {
    return ConnectorHealth.fromJson(
      json,
      databaseName: databaseInfo?.databaseName,
      edition: databaseInfo?.edition,
    );
  }

  Future<ConnectorHealth> getHealth() async {
    final response = await _request('/health', method: 'GET');
    return _healthFromJson(_asMap(response.data));
  }

  Future<DatabaseInfo?> getDatabaseInfo() async {
    try {
      final rows = await _getRows('/db/test');
      final first = rows.isNotEmpty ? rows.first : null;
      return first == null ? null : DatabaseInfo.fromJson(first);
    } catch (_) {
      return null;
    }
  }

  Future<SystemSnapshot> getSystemSnapshot() async {
    ConnectorHealth? health;
    DatabaseInfo? databaseInfo;
    try {
      health = await getHealth();
    } catch (_) {
      health = null;
    }
    try {
      databaseInfo = await getDatabaseInfo();
    } catch (_) {
      databaseInfo = null;
    }
    return SystemSnapshot(
      health: health,
      databaseInfo: databaseInfo,
    );
  }

  Future<ProductListPage> listProducts({
    int page = 1,
    int limit = 20,
    String? q,
    String? category,
    String? vendor,
    String? stockStatus,
  }) async {
    final rows = await _getMap('/products/list', query: {
      'page': page,
      'limit': limit,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
      if (vendor != null && vendor.trim().isNotEmpty) 'vendor': vendor.trim(),
      if (stockStatus != null && stockStatus.trim().isNotEmpty) 'stock_status': stockStatus.trim(),
    });
    return ProductListPage.fromJson(rows);
  }

  Future<List<ProductRecord>> searchProducts(String query, {int limit = 20}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const <ProductRecord>[];
    }
    final rows = await _getRows('/products/search', query: {'q': cleanQuery, 'limit': limit});
    return rows.map(ProductRecord.fromJson).take(limit).toList(growable: false);
  }

  Future<ProductRecord?> lookupBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) {
      return null;
    }
    try {
      final json = await _getMap('/barcode/lookup', query: {'code': clean});
      final row = _firstRow(json);
      return row == null ? null : ProductRecord.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<ProductRecord?> lookupProductDetail(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return null;
    }
    try {
      final json = await _getMap('/products/detail', query: {'q': clean});
      final row = _firstRow(json);
      return row == null ? null : ProductRecord.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<ProductRecord>> lowStockProducts() async => _loadProducts('/stock/low');

  Future<List<ProductRecord>> outOfStockProducts() async => _loadProducts('/stock/out');

  Future<List<ProductRecord>> negativeStockProducts() async => _loadProducts('/stock/negative');

  Future<Map<String, int>> getStockSummary() async {
    final json = await _getMap('/stock/summary');
    final rows = (json['rows'] as List<dynamic>? ?? const <dynamic>[]);
    final first = rows.isNotEmpty && rows.first is Map ? Map<String, dynamic>.from(rows.first as Map) : const <String, dynamic>{};
    return {
      'totalProducts': _intValue(first['total_products'] ?? first['totalProducts'], fallback: 0),
      'lowStockCount': _intValue(first['low_stock_count'] ?? first['lowStockCount'], fallback: 0),
      'outOfStockCount': _intValue(first['out_of_stock_count'] ?? first['outOfStockCount'], fallback: 0),
      'negativeStockCount': _intValue(first['negative_stock_count'] ?? first['negativeStockCount'], fallback: 0),
    };
  }

  Future<List<Map<String, dynamic>>> getCategories() => _getRows('/products/categories');

  Future<int> getProductCount() async {
    final json = await _getMap('/products/count');
    final rows = json['rows'];
    if (rows is List && rows.isNotEmpty && rows.first is Map) {
      final first = Map<String, dynamic>.from(rows.first as Map);
      return _intValue(first['total_products'], fallback: 0);
    }
    return 0;
  }

  Future<List<SalesRecord>> getTodaySales() async {
    final rows = await _getRows('/sales/today');
    return rows.map(SalesRecord.fromJson).toList(growable: false);
  }

  Future<SalesSummary> getTodaySalesSummary() async {
    final json = await _getMap('/sales/summary/today');
    final rows = json['rows'] as List<dynamic>? ?? const <dynamic>[];
    final first = rows.isNotEmpty && rows.first is Map ? Map<String, dynamic>.from(rows.first as Map) : const <String, dynamic>{};
    return SalesSummary.fromJson(first);
  }

  Future<List<Map<String, dynamic>>> getTopProductsToday() => _getRows('/sales/top-products/today');

  Future<List<VendorDirectoryRecord>> searchVendorDirectory({
    String? q,
    int page = 1,
    int limit = 25,
  }) async {
    final json = await _getMap('/vendors/search', query: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      'page': page,
      'limit': limit,
    });
    final rows = (json['rows'] as List<dynamic>? ?? json['vendors'] as List<dynamic>? ?? const <dynamic>[]);
    return rows.whereType<Map>().map((row) => VendorDirectoryRecord.fromJson(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  Future<List<VendorDirectoryRecord>> getVendors() => searchVendorDirectory(page: 1, limit: 100);

  Future<Map<String, dynamic>> getVendorSummary() async => _getMap('/vendors/summary');

  Future<Map<String, dynamic>> getVendorDetail(String vendorId) => _getMap('/vendors/${Uri.encodeComponent(vendorId)}');

  Future<List<VendorProductLink>> getVendorProducts(String vendorId) async {
    final json = await _getMap('/vendors/${Uri.encodeComponent(vendorId)}/products');
    final rows = (json['rows'] as List<dynamic>? ?? json['linked_products'] as List<dynamic>? ?? const <dynamic>[]);
    return rows.whereType<Map>().map((row) => VendorProductLink.fromJson(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  Future<List<PurchaseOrderRecord>> listPurchaseOrders() async {
    final rows = await _getRows('/purchase-orders');
    return rows.map(PurchaseOrderRecord.fromJson).toList(growable: false);
  }

  Future<Map<String, dynamic>> createPurchaseOrderDraft({
    String notes = 'Purchase request from Big Luna POS',
  }) async {
    _ensureWriteEnabled();
    final response = await _request(
      '/purchase-order-drafts',
      method: 'POST',
      data: {
        'notes': notes,
        'created_by': 'big-luna-mobile',
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getPurchaseOrderDraft(String draftId) => _getMap('/purchase-order-drafts/${Uri.encodeComponent(draftId)}');

  Future<Map<String, dynamic>> addPurchaseOrderDraftItem(
    String draftId,
    Map<String, dynamic> input,
  ) async {
    _ensureWriteEnabled();
    final response = await _request(
      '/purchase-order-drafts/${Uri.encodeComponent(draftId)}/items',
      method: 'POST',
      data: input,
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> groupPurchaseOrderDraftBySupplier(String draftId) async {
    _ensureWriteEnabled();
    final response = await _request(
      '/purchase-order-drafts/${Uri.encodeComponent(draftId)}/group-by-supplier',
      method: 'POST',
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createPurchaseOrdersFromDraft(
    String draftId, {
    String? notes,
  }) async {
    _ensureWriteEnabled();
    final response = await _request(
      '/purchase-order-drafts/${Uri.encodeComponent(draftId)}/create-purchase-orders',
      method: 'POST',
      data: {
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'idempotency_key': 'big-luna-${DateTime.now().millisecondsSinceEpoch}',
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> repairMissingPurchaseOrdersFromDraft(String draftId, {String? notes}) async {
    _ensureWriteEnabled();
    final response = await _request(
      '/purchase-order-drafts/${Uri.encodeComponent(draftId)}/repair-missing-purchase-orders',
      method: 'POST',
      data: {
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'idempotency_key': 'big-luna-${DateTime.now().millisecondsSinceEpoch}',
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getPurchaseOrder(String orderId) => _getMap('/purchase-orders/${Uri.encodeComponent(orderId)}');

  Future<Map<String, dynamic>> getPurchaseOrderReceivingStatus(String orderId) =>
      _getMap('/purchase-orders/${Uri.encodeComponent(orderId)}/receiving-status');

  Future<List<PurchaseOrderRecord>> listPurchaseOrderDrafts() async {
    final rows = await _getRows('/purchase-order-drafts');
    return rows.map(PurchaseOrderRecord.fromJson).toList(growable: false);
  }

  Future<List<GoodsReceiptRecord>> listGoodsReceipts() async {
    final rows = await _getRows('/goods-receiving');
    return rows.map(GoodsReceiptRecord.fromJson).toList(growable: false);
  }

  Future<Map<String, dynamic>> getGoodsReceipt(String receiptId) => _getMap('/goods-receiving/${Uri.encodeComponent(receiptId)}');

  Future<Map<String, dynamic>> saveGoodsReceipt({
    required String purchaseOrderId,
    required List<Map<String, dynamic>> lines,
    String receivedBy = 'big-luna-mobile',
    String notes = '',
    bool allowOverReceive = false,
  }) async {
    _ensureWriteEnabled();
    final response = await _request(
      '/goods-receiving',
      method: 'POST',
      data: {
        'purchase_order_id': purchaseOrderId,
        'received_by': receivedBy,
        'notes': notes,
        'idempotency_key': 'big-luna-${DateTime.now().millisecondsSinceEpoch}',
        'allow_over_receive': allowOverReceive,
        'lines': lines,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> deletePurchaseOrder(String orderId) async {
    _ensureWriteEnabled();
    final response = await _request('/purchase-orders/${Uri.encodeComponent(orderId)}', method: 'DELETE');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> deleteGoodsReceiving(String receiptId) async {
    _ensureWriteEnabled();
    final response = await _request('/goods-receiving/${Uri.encodeComponent(receiptId)}', method: 'DELETE');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createPurchaseOrderFromProduct(ProductRecord product) async {
    _ensureWriteEnabled();
    final supplierSummary = await getProductSupplierSummary(product.id).catchError((_) => <String, dynamic>{});
    final defaultVendorId = supplierSummary['defaultSupplierId']?.toString().trim() ?? '';
    final defaultVendorName = supplierSummary['defaultSupplierName']?.toString().trim() ?? '';
    final draft = await createPurchaseOrderDraft(notes: 'Mobile demo request from Big Luna POS');
    final draftId = draft['id']?.toString().trim() ?? '';
    if (draftId.isEmpty) {
      throw ApiException('Could not create purchase request draft.');
    }
    await addPurchaseOrderDraftItem(
      draftId,
      {
        'stock_id': product.id,
        'product_name_snapshot': product.name,
        'barcode_snapshot': product.barcode,
        'category_snapshot': product.category,
        'current_stock_snapshot': product.stockQty.toString(),
        'qty': 1,
        'unit_cost': product.cost ?? product.price,
        'selected_vendor_id': defaultVendorId,
        'selected_vendor_name_snapshot': defaultVendorName.isNotEmpty ? defaultVendorName : product.vendor,
        'notes': 'Created from mobile demo',
      },
    );
    final grouped = await groupPurchaseOrderDraftBySupplier(draftId);
    final response = await createPurchaseOrdersFromDraft(draftId, notes: 'Mobile demo PO create');
    return {
      'draft': grouped,
      'response': response,
      'supplier_summary': supplierSummary,
    };
  }

  Future<Map<String, dynamic>> saveFullGoodsReceipt(String orderId) async {
    _ensureWriteEnabled();
    final data = await getPurchaseOrder(orderId);
    final order = _asMap(data['order']);
    final lines = (data['lines'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    if (lines.isEmpty) {
      throw ApiException('No purchase order lines available for receiving.');
    }
    final payloadLines = lines.map((line) {
      final qty = _intValue(line['qty'] ?? line['ordered_qty'], fallback: 0);
      return {
        'purchase_order_line_id': line['id']?.toString() ?? line['purchase_order_line_id']?.toString() ?? '',
        'stock_id': line['stock_id']?.toString() ?? '',
        'product_name_snapshot': line['product_name_snapshot']?.toString() ?? '',
        'ordered_qty': qty,
        'received_qty': qty,
        'damaged_qty': 0,
        'accepted_qty': qty,
        'unit_cost': line['unit_cost'],
        'notes': 'Received from mobile demo',
      };
    }).toList(growable: false);
    final response = await saveGoodsReceipt(
      purchaseOrderId: order['id']?.toString() ?? orderId,
      receivedBy: 'big-luna-mobile',
      notes: 'Mobile demo receiving',
      lines: payloadLines,
      allowOverReceive: false,
    );
    return response;
  }

  Future<List<ExpirySummaryItem>> getExpirySummary() async {
    final json = await _getMap('/expiry/summary');
    final rows = json['rows'] as List<dynamic>? ?? const <dynamic>[];
    return rows.whereType<Map>().map((row) => ExpirySummaryItem.fromJson(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  Future<List<ExpiryLotRecord>> getExpiryLots(String stockId) async {
    final json = await _getMap('/expiry', query: {'stock_id': stockId});
    final rows = json['rows'] as List<dynamic>? ?? const <dynamic>[];
    return rows.whereType<Map>().map((row) => ExpiryLotRecord.fromJson(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  Future<ExpiryLotRecord> createExpiryLot(Map<String, dynamic> input) async {
    _ensureWriteEnabled();
    final response = await _request(
      '/expiry',
      method: 'POST',
      data: input,
    );
    return ExpiryLotRecord.fromJson(_asMap(response.data));
  }

  Future<List<Map<String, dynamic>>> getRecentAdjustments() async {
    final rows = await _getRows('/stock/recent-adjustments');
    return rows;
  }

  Future<StockAdjustmentResult> directAdjustStock({
    required String stockId,
    required String direction,
    required int qty,
    required String operatorName,
    required String reason,
    required String idempotencyKey,
  }) async {
    _ensureWriteEnabled();
    final response = await _request(
      '/stock/direct-adjust',
      method: 'POST',
      data: {
        'stock_id': stockId,
        'direction': direction,
        'qty': qty,
        'operator': operatorName,
        'reason': reason,
        'idempotency_key': idempotencyKey,
      },
    );
    final json = _asMap(response.data);
    final errorText = '${json['message'] ?? ''} ${json['error'] ?? ''}'.toLowerCase();
    if (json['ok'] != true || errorText.contains('write_mapping_not_confirmed')) {
      throw ApiException(
        errorText.contains('write_mapping_not_confirmed') ? 'Stock adjustment is not enabled yet.' : _extractMessage(json, fallback: 'Stock adjustment failed.'),
        statusCode: response.statusCode,
        payload: json,
      );
    }
    final row = _firstRow(json) ?? json;
    return StockAdjustmentResult.fromJson(row);
  }

  Future<List<Map<String, dynamic>>> getProductSuppliers(String stockId) async {
    final json = await _getMap('/product-suppliers', query: {'stock_id': stockId});
    final rows = json['rows'] as List<dynamic>? ?? const <dynamic>[];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  Future<Map<String, dynamic>> getProductSupplierSummary(String stockId) async {
    final json = await _getMap('/product-suppliers', query: {'stock_id': stockId});
    return _asMap(json['summary']);
  }

  Future<Map<String, dynamic>> getInventoryOverview() async {
    final stockSummary = await getStockSummary();
    final totalProducts = await getProductCount();
    return {
      'totalProducts': totalProducts,
      'lowStockCount': stockSummary['lowStockCount'] ?? 0,
      'outOfStockCount': stockSummary['outOfStockCount'] ?? 0,
      'negativeStockCount': stockSummary['negativeStockCount'] ?? 0,
    };
  }

  Future<List<ProductRecord>> _loadProducts(String path) async {
    final rows = await _getRows(path);
    return rows.map(ProductRecord.fromJson).toList(growable: false);
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  static int _intValue(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is num) return value.round();
    final parsed = int.tryParse(value.toString().replaceAll(',', '').trim());
    return parsed ?? fallback;
  }

  static Map<String, dynamic>? _firstRow(Map<String, dynamic> json) {
    final rows = json['rows'];
    if (rows is List && rows.isNotEmpty && rows.first is Map) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    if (json['draft'] is Map) return Map<String, dynamic>.from(json['draft'] as Map);
    if (json['product'] is Map) return Map<String, dynamic>.from(json['product'] as Map);
    if (json['row'] is Map) return Map<String, dynamic>.from(json['row'] as Map);
    if (json['vendor'] is Map) return Map<String, dynamic>.from(json['vendor'] as Map);
    if (json['order'] is Map) return Map<String, dynamic>.from(json['order'] as Map);
    if (json['receipt'] is Map) return Map<String, dynamic>.from(json['receipt'] as Map);
    return null;
  }

  static String _extractMessage(dynamic payload, {required String fallback}) {
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final message = map['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) return message;
      final error = map['error']?.toString().trim() ?? '';
      if (error.isNotEmpty) return error;
    }
    return fallback;
  }

  void _ensureWriteEnabled() {
    if (isDemoReadOnly) {
      throw ApiException('Demo Mode: Real data changes are disabled');
    }
  }
}
