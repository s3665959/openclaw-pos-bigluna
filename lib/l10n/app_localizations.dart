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
  String get grossProfit => isVietnamese ? 'Lợi nhuận gộp' : 'Gross Profit';
  String get grossMargin => isVietnamese ? 'Biên lợi nhuận gộp' : 'Gross Margin';
  String get orders => isVietnamese ? 'Đơn hàng' : 'Orders';
  String get itemsSold => isVietnamese ? 'Số lượng bán' : 'Items Sold';
  String get cogs => isVietnamese ? 'Giá vốn' : 'COGS';
  String get averageOrderValue => isVietnamese ? 'Giá trị đơn trung bình' : 'Average Order Value';
  String get topProductsByProfit => isVietnamese ? 'Sản phẩm lợi nhuận cao' : 'Top Products by Profit';
  String get topProductsByQuantity => isVietnamese ? 'Sản phẩm bán chạy' : 'Top Products by Quantity Sold';
  String get lowOrNegativeProfitItems => isVietnamese ? 'Sản phẩm lãi thấp hoặc âm' : 'Low / Negative Profit Items';
  String get pickDate => isVietnamese ? 'Chọn ngày' : 'Pick date';
  String get today => isVietnamese ? 'Hôm nay' : 'Today';
  String get noSalesData => isVietnamese ? 'Không có dữ liệu bán hàng' : 'No sales data';
  String get salesProfitReport => isVietnamese ? 'Báo cáo lợi nhuận gộp' : 'Gross Profit Report';
  String get selectedBusinessDate => isVietnamese ? 'Ngày kinh doanh đã chọn' : 'Selected business date';
  String get historicalCostBasisNote => isVietnamese
      ? 'Lợi nhuận lịch sử dùng giá vốn hiện tại từ POS khi dòng bán không có giá vốn tại thời điểm bán.'
      : 'Historical profit uses the current POS product cost when sale-line historical cost is not available.';
  String get salesReportRetry => isVietnamese ? 'Tải lại báo cáo' : 'Retry report';
  String get cost => isVietnamese ? 'Giá vốn' : 'Cost';
  String get retailPrice => isVietnamese ? 'Giá bán lẻ' : 'Retail Price';
  String get quantity => isVietnamese ? 'Số lượng' : 'Quantity';
  String get margin => isVietnamese ? 'Biên lợi nhuận' : 'Margin';
  String get totalSales => isVietnamese ? 'Tổng doanh thu' : 'Total Sales';
  String get dailyBusinessReview => isVietnamese ? 'Xem nhanh kết quả kinh doanh theo ngày' : 'Daily business review';
  String get liveToday => isVietnamese ? 'Dữ liệu hôm nay' : 'Live today';
  String get archiveSource => isVietnamese ? 'Dữ liệu lưu trữ' : 'Archive';
  String get unknownSource => isVietnamese ? 'Nguồn không rõ' : 'Unknown source';
  String get noRankedProducts => isVietnamese ? 'Chưa có xếp hạng sản phẩm' : 'No ranked products';
  String get noQuantityAnalysis => isVietnamese ? 'Chưa có phân tích số lượng' : 'No quantity analysis';
  String get noLowMarginItems => isVietnamese ? 'Không có sản phẩm lãi thấp' : 'No low-margin items';
  String get allAboveMarginThreshold => isVietnamese ? 'Tất cả sản phẩm được phân tích đều cao hơn ngưỡng lợi nhuận thấp.' : 'All analysed products are above the low-margin threshold.';
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
