import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.apiToken,
  });

  final String apiBaseUrl;
  final String apiToken;

  factory AppConfig.fromEnv() {
    final rawBaseUrl = dotenv.env['API_BASE_URL']?.trim() ?? '';
    final rawToken = dotenv.env['API_TOKEN']?.trim() ?? '';
    final apiBaseUrl = rawBaseUrl.isEmpty ? 'https://openclaw.ganseeds.com' : rawBaseUrl;

    return AppConfig(
      apiBaseUrl: apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl,
      apiToken: rawToken,
    );
  }
}
