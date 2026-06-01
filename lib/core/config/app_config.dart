import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.apiToken,
    required this.demoReadOnly,
  });

  final String apiBaseUrl;
  final String apiToken;
  final bool demoReadOnly;

  factory AppConfig.fromEnv() {
    final rawBaseUrl = _env('API_BASE_URL');
    final rawToken = _env('API_TOKEN');
    final rawDemoReadOnly = _env('DEMO_READ_ONLY');
    final apiBaseUrl = _normalizeApiBaseUrl(rawBaseUrl);
    final demoReadOnly = rawDemoReadOnly.isEmpty ? true : _parseBool(rawDemoReadOnly, fallback: true);

    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      apiToken: rawToken,
      demoReadOnly: demoReadOnly,
    );
  }
}

String _normalizeApiBaseUrl(String rawBaseUrl) {
  final trimmed = (rawBaseUrl.isEmpty ? 'https://openclaw.ganseeds.com' : rawBaseUrl).trim();
  final withoutTrailingSlash = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  final parsed = Uri.tryParse(withoutTrailingSlash);
  final path = parsed?.path ?? '';

  if (withoutTrailingSlash.endsWith('/pos-dashboard/api')) {
    return withoutTrailingSlash;
  }
  if (path.isEmpty || path == '/' || path == '/pos-dashboard' || path == '/pos-dashboard/') {
    return '$withoutTrailingSlash/pos-dashboard/api';
  }
  return withoutTrailingSlash;
}

String _env(String key) {
  try {
    return dotenv.env[key]?.trim() ?? '';
  } catch (_) {
    return '';
  }
}

bool _parseBool(String raw, {required bool fallback}) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return fallback;
  if (value == 'true' || value == '1' || value == 'yes' || value == 'y' || value == 'on') return true;
  if (value == 'false' || value == '0' || value == 'no' || value == 'n' || value == 'off') return false;
  return fallback;
}
