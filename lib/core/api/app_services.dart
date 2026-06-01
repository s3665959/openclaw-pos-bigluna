import '../config/app_config.dart';
import 'openclaw_api.dart';

class AppServices {
  AppServices._();

  static OpenClawApi? _api;
  static AppConfig? _config;

  static OpenClawApi get api => _api ??= OpenClawApi(config: config);
  static AppConfig get config => _config ??= AppConfig.fromEnv();

  static void init() {
    _config = AppConfig.fromEnv();
    _api = OpenClawApi(config: _config);
  }
}
