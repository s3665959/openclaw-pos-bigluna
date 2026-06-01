import 'openclaw_api.dart';

class AppServices {
  AppServices._();

  static OpenClawApi? _api;

  static OpenClawApi get api => _api ??= OpenClawApi();

  static void init() {
    _api = OpenClawApi();
  }
}
