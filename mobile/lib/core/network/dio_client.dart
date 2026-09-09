import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class DioClient {
  late final Dio dio;
  String _currentBaseUrl = ApiConstants.defaultBaseUrl;

  String get currentBaseUrl => _currentBaseUrl;

  DioClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: _currentBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => print('[Dio] $obj'),
      ),
    );

    _loadPersistedBaseUrl();
  }

  Future<void> _loadPersistedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(ApiConstants.prefsBaseUrlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        updateBaseUrl(savedUrl, persist: false);
      }
    } catch (e) {
      print('Failed to load persisted base URL: $e');
    }
  }

  Future<void> updateBaseUrl(String newUrl, {bool persist = true}) async {
    String cleanUrl = newUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    _currentBaseUrl = cleanUrl;
    dio.options.baseUrl = cleanUrl;

    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConstants.prefsBaseUrlKey, cleanUrl);
      } catch (e) {
        print('Failed to save base URL: $e');
      }
    }
  }
}
