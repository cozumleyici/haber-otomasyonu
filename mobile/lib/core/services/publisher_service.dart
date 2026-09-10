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

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  String _formatChatId(String rawChatId) {
    final clean = rawChatId.trim();
    if (clean.isEmpty) return clean;
    if (!clean.startsWith('@') && !clean.startsWith('-')) {
      return '@$clean';
    }
    return clean;
  }

  String _extractTelegramError(dynamic error) {
    if (error is DioException && error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map && data['description'] != null) {
        final desc = data['description'].toString();
        if (desc.contains('chat not found')) {
          return 'Kanal bulunamadı: Botu kanalınıza "Yönetici (Admin)" olarak eklediğinizden ve kanal adını başında @ olacak şekilde (Örn: @haberkanalim) girdiğinizden emin olun.';
        } else if (desc.contains('bot was blocked')) {
          return 'Bot engellenmiş: Lütfen botu kanalda yönetici yapın.';
        } else if (desc.contains('not enough rights')) {
          return 'Yetki yetersiz: Botun kanala mesaj gönderme yetkisi bulunmuyor.';
        }
        return desc;
      }
    }
    return error.toString();
  }

  /// Onaylanan haberi doğrudan Telegram Kanalına yayınlar
  Future<PublishResult> publishNews({
    required String finalTitle,
    required String finalContent,
    String? imageUrl,
    List<String>? targetPlatforms,
  }) async {
    final settings = await DatabaseHelper.instance.getAllSettings();
    final botToken = (settings['telegram_bot_token'] ?? '').trim();
    final rawChatId = (settings['telegram_chat_id'] ?? '').trim();

    if (botToken.isEmpty || rawChatId.isEmpty) {
      return PublishResult(
        success: false,
        message: 'Lütfen ayarlardan Telegram Bot Token ve Kanal ID bilgilerini kaydedin.',
      );
    }

    final chatId = _formatChatId(rawChatId);

    try {
      final safeTitle = _escapeHtml(finalTitle.trim());
      final safeContent = _escapeHtml(finalContent.trim());
      final fullHtmlText = '<b>$safeTitle</b>\n\n$safeContent';

      // 1. Durum: Görsel var ise
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        final cleanImageUrl = imageUrl.trim();

        // Telegram sendPhoto caption sınırı en fazla 1024 karakterdir
        if (fullHtmlText.length <= 1024) {
          final photoSuccess = await _trySendPhoto(
            botToken: botToken,
            chatId: chatId,
            photoUrl: cleanImageUrl,
            caption: fullHtmlText,
          );
          if (photoSuccess) {
            return PublishResult(success: true, message: 'Haber Telegram kanalınıza başarıyla yayınlandı!');
          }
        } else {
          // Metin 1024 karakterden uzun ise: Fotoğrafı başlık + ilk kısım ile gönder, kalanını tamamla
          final maxCaptionLength = 1000 - safeTitle.length - 15;
          final splitIndex = _findSplitPoint(safeContent, maxCaptionLength > 100 ? maxCaptionLength : 500);
          final firstPart = safeContent.substring(0, splitIndex).trim();
          final remainingPart = safeContent.substring(splitIndex).trim();

          final photoCaption = '<b>$safeTitle</b>\n\n$firstPart';
          final photoSuccess = await _trySendPhoto(
            botToken: botToken,
            chatId: chatId,
            photoUrl: cleanImageUrl,
            caption: photoCaption,
          );

          if (photoSuccess) {
            if (remainingPart.isNotEmpty) {
              await _trySendMessage(
                botToken: botToken,
                chatId: chatId,
                text: remainingPart,
              );
            }
            return PublishResult(success: true, message: 'Haber Telegram kanalınıza başarıyla yayınlandı!');
          }
        }
      }

      // 2. Durum: Görsel yoksa veya fotoğraf gönderimi başarısız olduysa doğrudan sendMessage ile gönder
      final messageSuccess = await _trySendMessage(
        botToken: botToken,
        chatId: chatId,
        text: fullHtmlText,
      );

      if (messageSuccess) {
        return PublishResult(success: true, message: 'Haber Telegram kanalınıza başarıyla yayınlandı!');
      }

      return PublishResult(success: false, message: 'Telegram mesajı gönderilemedi.');
    } catch (e) {
      return PublishResult(success: false, message: 'Telegram Hatası: ${_extractTelegramError(e)}');
    }
  }

  Future<bool> _trySendPhoto({
    required String botToken,
    required String chatId,
    required String photoUrl,
    required String caption,
  }) async {
    final url = 'https://api.telegram.org/bot$botToken/sendPhoto';
    try {
      final res = await _dio.post(url, data: {
        'chat_id': chatId,
        'photo': photoUrl,
        'caption': caption,
        'parse_mode': 'HTML',
      });
      return res.statusCode == 200 && res.data['ok'] == true;
    } on DioException catch (e) {
      final desc = e.response?.data is Map ? e.response?.data['description']?.toString() : null;
      print('[PublisherService] sendPhoto failed: $desc');

      // Parse hatası verdiyse HTML etiketlerini temizleyip düz metin olarak tekrar dene
      if (desc != null && (desc.contains("can't parse") || desc.contains("entity"))) {
        try {
          final retryRes = await _dio.post(url, data: {
            'chat_id': chatId,
            'photo': photoUrl,
            'caption': caption.replaceAll(RegExp(r'<[^>]*>'), ''),
          });
          return retryRes.statusCode == 200 && retryRes.data['ok'] == true;
        } catch (_) {}
      }

      // Kanal bulunamadı veya yetki hatasıysa hatayı fırlat
      if (desc != null &&
          (desc.contains('chat not found') ||
              desc.contains('Unauthorized') ||
              desc.contains('not a member') ||
              desc.contains('administrator'))) {
        rethrow;
      }

      // Fotoğraf URL'si kaynaklı bir hataysa sendMessage fallback'ine geç
      return false;
    }
  }

  Future<bool> _trySendMessage({
    required String botToken,
    required String chatId,
    required String text,
  }) async {
    final url = 'https://api.telegram.org/bot$botToken/sendMessage';
    try {
      final res = await _dio.post(url, data: {
        'chat_id': chatId,
        'text': text,
        'parse_mode': 'HTML',
      });
      return res.statusCode == 200 && res.data['ok'] == true;
    } on DioException catch (e) {
      final desc = e.response?.data is Map ? e.response?.data['description']?.toString() : null;
      print('[PublisherService] sendMessage failed: $desc');

      // Parse hatası verdiyse düz metin dene
      if (desc != null && (desc.contains("can't parse") || desc.contains("entity"))) {
        try {
          final retryRes = await _dio.post(url, data: {
            'chat_id': chatId,
            'text': text.replaceAll(RegExp(r'<[^>]*>'), ''),
          });
          return retryRes.statusCode == 200 && retryRes.data['ok'] == true;
        } catch (_) {}
      }

      rethrow;
    }
  }

  int _findSplitPoint(String text, int maxLength) {
    if (text.length <= maxLength) return text.length;
    final searchRange = text.substring(0, maxLength);
    final lastNewline = searchRange.lastIndexOf('\n\n');
    if (lastNewline > maxLength ~/ 2) return lastNewline;
    final lastDot = searchRange.lastIndexOf('. ');
    if (lastDot > maxLength ~/ 2) return lastDot + 1;
    final lastSpace = searchRange.lastIndexOf(' ');
    if (lastSpace > maxLength ~/ 2) return lastSpace;
    return maxLength;
  }

  /// Telegram bağlantısını test eder
  Future<Map<String, dynamic>> testTelegram(String botToken, String chatId) async {
    try {
      final cleanToken = botToken.trim();
      final formattedChat = _formatChatId(chatId);

      final meRes = await _dio.get('https://api.telegram.org/bot$cleanToken/getMe');
      if (meRes.statusCode != 200 || meRes.data['ok'] != true) {
        return {'success': false, 'message': 'Geçersiz Bot Token.'};
      }

      final botName = meRes.data['result']['username'];

      if (formattedChat.isNotEmpty) {
        await _dio.post('https://api.telegram.org/bot$cleanToken/sendMessage', data: {
          'chat_id': formattedChat,
          'text': '🤖 <b>Haber Otomasyonu Test Mesajı</b>\n\n✅ Bot başarıyla bağlandı!\n• Bot: @$botName\n• Zaman: ${DateTime.now().toLocal()}',
          'parse_mode': 'HTML',
        });
      }

      return {
        'success': true,
        'message': 'Bağlantı başarılı! Bot: @$botName' +
            (formattedChat.isNotEmpty ? ' (Kanalınıza test mesajı gönderildi)' : ''),
      };
    } catch (e) {
      return {'success': false, 'message': 'Telegram Hatası: ${_extractTelegramError(e)}'};
    }
  }
}
