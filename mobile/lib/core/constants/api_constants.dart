/// API Constants and Endpoint Routes for the News HITL System
class ApiConstants {
  // Default base URL for testing. 
  // On Android emulator, 'http://10.0.2.2:5678' maps to host localhost:5678.
  // On physical devices or remote VPS, set to 'http://<YOUR_VPS_IP>:5678'.
  static const String defaultBaseUrl = 'http://10.0.2.2:5678';

  // SharedPreferences key for persisting the dynamic VPS Base URL
  static const String prefsBaseUrlKey = 'vps_base_url';

  // Endpoint paths matching n8n Webhook definitions
  static const String pendingNewsEndpoint = '/webhook/news-pending';
  static const String actionEndpoint = '/webhook/news-action';

  // Network configuration
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 15);
}
