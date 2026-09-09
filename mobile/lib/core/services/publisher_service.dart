import 'package:dio/dio.dart';
import '../database/database_helper.dart';

class PublishResult {
  final bool success;
  final String message;

  PublishResult({required this.success, required this.message});
}

class PublisherService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// Onaylanan haberi doğrudan Telegram Kanalına yayınlar
  Future<PublishResult> publishNews({
    required String finalTitle,
    required String finalContent,
    String? imageUrl,
    List<String>? targetPlatforms,
  }) async {
    final settings = await DatabaseHelper.instance.getAllSettings();
    final botToken = settings['telegram_bot_token'] ?? '';
    final chatId = settings['telegram_chat_id'] ?? '';

    if (botToken.isEmpty || chatId.isEmpty) {
      return PublishResult(
        success: false,
        message: 'Lütfen ayarlardan Telegram Bot Token ve Kanal ID bilgilerini kaydedin.',
      );
    }

    try {
      final captionOrText = '*$finalTitle*\n\n$finalContent';

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final url = 'https://api.telegram.org/bot$botToken/sendPhoto';
        final res = await _dio.post(url, data: {
          'chat_id': chatId,
          'photo': imageUrl,
          'caption': captionOrText,
          'parse_mode': 'Markdown',
        });
        if (res.statusCode == 200 && res.data['ok'] == true) {
          return PublishResult(success: true, message: 'Haber Telegram kanalınıza başarıyla yayınlandı!');
        }
      } else {
        final url = 'https://api.telegram.org/bot$botToken/sendMessage';
        final res = await _dio.post(url, data: {
          'chat_id': chatId,
          'text': captionOrText,
          'parse_mode': 'Markdown',
        });
        if (res.statusCode == 200 && res.data['ok'] == true) {
          return PublishResult(success: true, message: 'Haber Telegram kanalınıza başarıyla yayınlandı!');
        }
      }

      return PublishResult(success: false, message: 'Telegram mesajı gönderilemedi.');
    } catch (e) {
      return PublishResult(success: false, message: 'Telegram Hatası: $e');
    }
  }

  /// Telegram bağlantısını test eder
  Future<Map<String, dynamic>> testTelegram(String botToken, String chatId) async {
    try {
      final meRes = await _dio.get('https://api.telegram.org/bot$botToken/getMe');
      if (meRes.statusCode != 200 || meRes.data['ok'] != true) {
        return {'success': false, 'message': 'Geçersiz Bot Token.'};
      }

      final botName = meRes.data['result']['username'];

      if (chatId.isNotEmpty) {
        await _dio.post('https://api.telegram.org/bot$botToken/sendMessage', data: {
          'chat_id': chatId,
          'text': '🤖 *Haber Otomasyonu Test Mesajı*\n\n✅ Bot başarıyla bağlandı!\n• Bot: @$botName\n• Zaman: ${DateTime.now().toLocal()}',
          'parse_mode': 'Markdown',
        });
      }

      return {
        'success': true,
        'message': 'Bağlantı başarılı! Bot: @$botName' +
            (chatId.isNotEmpty ? ' (Kanalınıza test mesajı gönderildi)' : ''),
      };
    } catch (e) {
      return {'success': false, 'message': 'Telegram Hatası: $e'};
    }
  }
}
