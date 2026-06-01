import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final result = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return result ?? AppLocalizations(const Locale('en'));
  }

  bool get isVietnamese => locale.languageCode == 'vi';

  String get appName => isVietnamese ? 'Big Luna POS' : 'Big Luna POS';
  String get dashboard => isVietnamese ? 'Bảng điều khiển' : 'Dashboard';
  String get systemStatus => isVietnamese ? 'Trạng thái hệ thống' : 'System Status';
  String get products => isVietnamese ? 'Sản phẩm' : 'Products';
  String get scanBarcode => isVietnamese ? 'Quét mã vạch' : 'Scan Barcode';
  String get inventory => isVietnamese ? 'Tồn kho' : 'Inventory';
  String get sales => isVietnamese ? 'Bán hàng' : 'Sales';
  String get vendors => isVietnamese ? 'Nhà cung cấp' : 'Vendors';
  String get purchaseOrders => isVietnamese ? 'Đơn mua hàng' : 'Purchase Orders';
  String get goodsReceiving => isVietnamese ? 'Nhập hàng' : 'Goods Receiving';
  String get stockAdjustment => isVietnamese ? 'Điều chỉnh tồn kho' : 'Stock Adjustment';
  String get expiryLots => isVietnamese ? 'Lô hết hạn' : 'Expiry Lots';
  String get settings => isVietnamese ? 'Cài đặt' : 'Settings';
  String get english => isVietnamese ? 'English' : 'English';
  String get vietnamese => isVietnamese ? 'Tiếng Việt' : 'Tiếng Việt';
  String get demoModeDisabledBanner => isVietnamese ? 'Chế độ demo - Đã tắt thay đổi dữ liệu thực' : 'Demo Mode — Real data changes are disabled';
  String get demoModeEnabledBanner => isVietnamese ? 'Môi trường POS thử nghiệm - Đã bật ghi dữ liệu thực' : 'POS Test Environment — Real data changes enabled';
  String get loading => isVietnamese ? 'Đang tải...' : 'Loading...';
  String get loadingDashboard => isVietnamese ? 'Đang tải Big Luna POS...' : 'Loading Big Luna POS...';
  String get loadingStatus => isVietnamese ? 'Đang kiểm tra trạng thái...' : 'Checking system status...';
  String get loadingProducts => isVietnamese ? 'Đang tải sản phẩm...' : 'Loading products...';
  String get loadingSales => isVietnamese ? 'Đang tải doanh số...' : 'Loading sales...';
  String get loadingInventory => isVietnamese ? 'Đang tải tồn kho...' : 'Loading inventory...';
  String get loadingVendors => isVietnamese ? 'Đang tải nhà cung cấp...' : 'Loading vendors...';
  String get loadingPurchaseOrders => isVietnamese ? 'Đang tải đơn mua hàng...' : 'Loading purchase orders...';
  String get loadingData => isVietnamese ? 'Đang tải dữ liệu...' : 'Loading data...';
  String get retry => isVietnamese ? 'Thử lại' : 'Retry';
  String get refresh => isVietnamese ? 'Làm mới' : 'Refresh';
  String get search => isVietnamese ? 'Tìm kiếm' : 'Search';
  String get clear => isVietnamese ? 'Xóa' : 'Clear';
  String get save => isVietnamese ? 'Lưu' : 'Save';
  String get cancel => isVietnamese ? 'Hủy' : 'Cancel';
  String get confirm => isVietnamese ? 'Xác nhận' : 'Confirm';
  String get readOnly => isVietnamese ? 'Chế độ đọc' : 'Read only';
  String get writeEnabled => isVietnamese ? 'Đã bật ghi' : 'Write enabled';
  String get notProvidedByApi => isVietnamese ? 'Không được API cung cấp' : 'Not provided by API';
  String get connectionFailed => isVietnamese ? 'Kết nối thất bại' : 'Connection failed';
  String get noData => isVietnamese ? 'Chưa có dữ liệu' : 'No data';
  String get unknown => isVietnamese ? 'Không rõ' : 'Unknown';
  String get dashboardOverview => isVietnamese ? 'Tổng quan hệ thống' : 'System overview';
  String get demoMenu => isVietnamese ? 'Menu demo' : 'Demo menu';
  String get settingsLanguage => isVietnamese ? 'Ngôn ngữ' : 'Language';
  String get englishLabel => 'English';
  String get vietnameseLabel => 'Tiếng Việt';
  String get backendOnline => isVietnamese ? 'Trực tuyến' : 'Online';
  String get backendOffline => isVietnamese ? 'Ngoại tuyến' : 'Offline';
  String get noReceiptList => isVietnamese ? 'Chưa có phiếu nhập' : 'No goods receipts';
  String get noAdjustments => isVietnamese ? 'Chưa có điều chỉnh gần đây' : 'No recent adjustments';
  String get noLots => isVietnamese ? 'Chưa có lô' : 'No lots';
  String get noPo => isVietnamese ? 'Chưa có PO' : 'No purchase orders';
  String get noProducts => isVietnamese ? 'Không có sản phẩm' : 'No products';
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en' || locale.languageCode == 'vi';

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

