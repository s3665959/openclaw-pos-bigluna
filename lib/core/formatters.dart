import 'package:intl/intl.dart';

final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '฿', decimalDigits: 2);
final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');
final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

String formatMoney(num value) => _currencyFormat.format(value);

String formatDateTimeText(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '-';
  final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (parsed == null) return raw;
  return _dateTimeFormat.format(parsed.toLocal());
}

String formatDateText(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '-';
  final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (parsed == null) return raw;
  return _dateFormat.format(parsed.toLocal());
}

String formatQuantity(num value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}
