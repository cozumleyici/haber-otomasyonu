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
        if (desc.contains("can't send messages to the bot") || desc.contains("cannot send messages to the bot")) {
          return 'Girdiğiniz kullanıcı adı botun kendisine aittir! Buraya botun adını değil, haberlerin paylaşılacağı Telegram KANALINIZIN adını (Örn: @haberkanalim) yazmalısınız. Botu da o kanala Yönetici (Admin) olarak eklemelisiniz.';
        } else if (desc.contains('chat not found')) {
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

  String _extractFacebookError(dynamic error) {
    if (error is DioException && error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map && data['error'] != null) {
        final err = data['error'];
        if (err is Map) {
          final msg = err['message']?.toString() ?? '';
          final code = err['code'];
          if (code == 190) {
            return 'Facebook Erişim Jetonu (Access Token) süresi dolmuş veya geçersiz. Lütfen yenileyin.';
          } else if (code == 200 || code == 10) {
            return 'Facebook Sayfa Yetkisi Yetersiz: Jetonun "pages_manage_posts" ve "pages_read_engagement" izinlerine sahip olduğundan emin olun.';
          } else if (code == 100) {
            return 'Geçersiz parametre veya Sayfa ID: $msg';
          }
          return msg.isNotEmpty ? msg : 'Facebook API Hatası (Kod: $code)';
        }
      }
    }
    return error.toString();
  }

  /// Onaylanan haberi seçilen tüm hedef platformlara (Telegram, Facebook) yayınlar
  Future<PublishResult> publishNews({
    required String finalTitle,
    required String finalContent,
    String? imageUrl,
    List<String>? targetPlatforms,
  }) async {
    final settings = await DatabaseHelper.instance.getAllSettings();
    final platforms = targetPlatforms ?? ['telegram', 'facebook'];

    final shouldPublishTelegram = platforms.contains('telegram');
    final shouldPublishFacebook = platforms.contains('facebook');

    if (!shouldPublishTelegram && !shouldPublishFacebook) {
      return PublishResult(
        success: false,
        message: 'Yayınlanacak en az bir platform (Telegram veya Facebook) seçilmelidir.',
      );
    }

    final successTargets = <String>[];
    final failureMessages = <String>[];

    // 1. Telegram Yayını
    if (shouldPublishTelegram) {
      final botToken = (settings['telegram_bot_token'] ?? '').trim();
      final rawChatId = (settings['telegram_chat_id'] ?? '').trim();

      if (botToken.isEmpty || rawChatId.isEmpty) {
        failureMessages.add('Telegram: Ayarlarda Bot Token veya Kanal ID girilmemiş.');
      } else {
        final tResult = await publishToTelegram(
          botToken: botToken,
          chatId: _formatChatId(rawChatId),
          finalTitle: finalTitle,
          finalContent: finalContent,
          imageUrl: imageUrl,
        );
        if (tResult.success) {
          successTargets.add('Telegram Kanalı');
        } else {
          failureMessages.add('Telegram: ${tResult.message}');
        }
      }
    }

    // 2. Facebook Sayfa Yayını
    if (shouldPublishFacebook) {
      final fbPageId = (settings['facebook_page_id'] ?? '').trim();
      final fbToken = (settings['facebook_page_token'] ?? '').trim();

      if (fbPageId.isEmpty || fbToken.isEmpty) {
        failureMessages.add('Facebook: Ayarlarda Sayfa ID veya Erişim Jetonu girilmemiş.');
      } else {
        final fbResult = await publishToFacebook(
          pageId: fbPageId,
          pageAccessToken: fbToken,
          finalTitle: finalTitle,
          finalContent: finalContent,
          imageUrl: imageUrl,
        );
        if (fbResult.success) {
          successTargets.add('Facebook Sayfası');
        } else {
          failureMessages.add('Facebook: ${fbResult.message}');
        }
      }
    }

    if (successTargets.isNotEmpty && failureMessages.isEmpty) {
      return PublishResult(
        success: true,
        message: 'Haber başarıyla yayınlandı: ${successTargets.join(' & ')}',
      );
    } else if (successTargets.isNotEmpty && failureMessages.isNotEmpty) {
      return PublishResult(
        success: true,
        message: '${successTargets.join(' & ')} yayınlandı. Uyarılar: ${failureMessages.join(', ')}',
      );
    } else {
      return PublishResult(
        success: false,
        message: failureMessages.join(' | '),
      );
    }
  }

  /// Telegram Kanalına Yayınlama
  Future<PublishResult> publishToTelegram({
    required String botToken,
    required String chatId,
    required String finalTitle,
    required String finalContent,
    String? imageUrl,
  }) async {
    try {
      final safeTitle = _escapeHtml(finalTitle.trim());
      final safeContent = _escapeHtml(finalContent.trim());
      final fullHtmlText = '<b>$safeTitle</b>\n\n$safeContent';

      // 1. Görsel var ise
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        final cleanImageUrl = imageUrl.trim();

        // Telegram sendPhoto caption sınırı en fazla 1024 karakterdir
        if (fullHtmlText.length <= 1000) {
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
          // Metin 1000 karakterden uzun ise: Fotoğrafı başlık + ilk kısım ile gönder, kalanını takip eden mesaj olarak gönder
          final titlePrefix = '<b>$safeTitle</b>\n\n';
          final availableForContent = 980 - titlePrefix.length;

          String photoCaption;
          String remainingPart;

          if (availableForContent > 80) {
            final splitIndex = _findSplitPoint(safeContent, availableForContent);
            final firstPart = safeContent.substring(0, splitIndex).trim();
            photoCaption = '$titlePrefix$firstPart';
            remainingPart = safeContent.substring(splitIndex).trim();
          } else {
            photoCaption = titlePrefix.length <= 1000
                ? titlePrefix.trim()
                : '<b>${_escapeHtml(finalTitle.trim().substring(0, 950))}...</b>';
            remainingPart = safeContent;
          }

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

      // 2. Görsel yoksa veya fotoğraf gönderimi başarısız olduysa doğrudan sendMessage ile parçalı gönder
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

  /// Facebook Sayfasına Yayınlama (Graph API v19.0)
  Future<PublishResult> publishToFacebook({
    required String pageId,
    required String pageAccessToken,
    required String finalTitle,
    required String finalContent,
    String? imageUrl,
  }) async {
    final cleanId = pageId.trim();
    final cleanToken = pageAccessToken.trim();

    if (cleanId.isEmpty || cleanToken.isEmpty) {
      return PublishResult(
        success: false,
        message: 'Facebook Sayfa ID veya Erişim Jetonu eksik.',
      );
    }

    try {
      final messageText = '$finalTitle\n\n$finalContent';

      // 1. Görsel var ise öncelikle /photos uç noktasına gönder
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        final cleanImageUrl = imageUrl.trim();

        // 1a. Cihaz üzerinden görseli indirip Multipart FormData olarak yükle
        try {
          final imgRes = await _dio.get<List<int>>(
            cleanImageUrl,
            options: Options(
              responseType: ResponseType.bytes,
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
              },
            ),
          );

          if (imgRes.statusCode == 200 && imgRes.data != null && imgRes.data!.isNotEmpty) {
            final formData = FormData.fromMap({
              'caption': messageText,
              'access_token': cleanToken,
              'source': MultipartFile.fromBytes(
                imgRes.data!,
                filename: 'news_image.jpg',
              ),
            });

            final photoRes = await _dio.post(
              'https://graph.facebook.com/v19.0/$cleanId/photos',
              data: formData,
            );

            if (photoRes.statusCode == 200 && photoRes.data['id'] != null) {
              return PublishResult(
                success: true,
                message: 'Facebook Sayfanızda fotoğraflı olarak başarıyla yayınlandı!',
              );
            }
          }
        } catch (e) {
          print('[PublisherService] Facebook multipart upload failed, trying direct URL: $e');
        }

        // 1b. Doğrudan resim URL'si ile /photos uç noktasına yükle
        try {
          final photoRes = await _dio.post(
            'https://graph.facebook.com/v19.0/$cleanId/photos',
            data: {
              'caption': messageText,
              'url': cleanImageUrl,
              'access_token': cleanToken,
            },
          );

          if (photoRes.statusCode == 200 && photoRes.data['id'] != null) {
            return PublishResult(
              success: true,
              message: 'Facebook Sayfanızda başarıyla yayınlandı!',
            );
          }
        } catch (e) {
          print('[PublisherService] Facebook photo url upload failed, falling back to feed: $e');
        }
      }

      // 2. Görsel yoksa veya fotoğraf yükleme başarısız olursa /feed uç noktasına metin olarak gönder
      final feedRes = await _dio.post(
        'https://graph.facebook.com/v19.0/$cleanId/feed',
        data: {
          'message': messageText,
          'access_token': cleanToken,
        },
      );

      if (feedRes.statusCode == 200 && feedRes.data['id'] != null) {
        return PublishResult(
          success: true,
          message: 'Facebook Sayfanızda başarıyla yayınlandı!',
        );
      }

      return PublishResult(success: false, message: 'Facebook paylaşımı tamamlanamadı.');
    } catch (e) {
      return PublishResult(
        success: false,
        message: 'Facebook Hatası: ${_extractFacebookError(e)}',
      );
    }
  }

  Future<bool> _trySendPhoto({
    required String botToken,
    required String chatId,
    required String photoUrl,
    required String caption,
  }) async {
    final url = 'https://api.telegram.org/bot$botToken/sendPhoto';

    // 1. Önce görseli cihazda indirip Multipart FormData olarak Telegram'a yüklemeyi dene
    try {
      final imgResponse = await _dio.get<List<int>>(
        photoUrl,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          },
        ),
      );

      if (imgResponse.statusCode == 200 &&
          imgResponse.data != null &&
          imgResponse.data!.isNotEmpty) {
        final formData = FormData.fromMap({
          'chat_id': chatId,
          'caption': caption,
          'parse_mode': 'HTML',
          'photo': MultipartFile.fromBytes(
            imgResponse.data!,
            filename: 'news_image.jpg',
          ),
        });

        final res = await _dio.post(url, data: formData);
        if (res.statusCode == 200 && res.data['ok'] == true) {
          return true;
        }
      }
    } catch (e) {
      print('[PublisherService] Multipart sendPhoto failed: $e');
    }

    // 2. Eğer cihazdan indirme başarısız olursa doğrudan URL olarak Telegram'a ilet
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
      print('[PublisherService] direct sendPhoto failed: $desc');

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

      if (desc != null &&
          (desc.contains('chat not found') ||
              desc.contains('Unauthorized') ||
              desc.contains('not a member') ||
              desc.contains('administrator') ||
              desc.contains("can't send messages to the bot"))) {
        rethrow;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Telegram sendMessage sınırını (4096 karakter) aşmamak için otomatik parçalar halinde gönderir
  Future<bool> _trySendMessage({
    required String botToken,
    required String chatId,
    required String text,
  }) async {
    final chunks = _splitTextIntoChunks(text, maxChunkSize: 3900);

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final success = await _sendSingleMessageChunk(
        botToken: botToken,
        chatId: chatId,
        text: chunk,
      );
      if (!success) return false;
      if (i < chunks.length - 1) {
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }
    return true;
  }

  Future<bool> _sendSingleMessageChunk({
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
      print('[PublisherService] sendMessage chunk failed: $desc');

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

  List<String> _splitTextIntoChunks(String text, {int maxChunkSize = 3900}) {
    if (text.length <= maxChunkSize) return [text];

    final chunks = <String>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      if (remaining.length <= maxChunkSize) {
        chunks.add(remaining);
        break;
      }

      final splitIndex = _findSplitPoint(remaining, maxChunkSize);
      final actualCut = (splitIndex <= 0 || splitIndex > maxChunkSize) ? maxChunkSize : splitIndex;
      chunks.add(remaining.substring(0, actualCut).trim());
      remaining = remaining.substring(actualCut).trim();
    }

    return chunks;
  }

  int _findSplitPoint(String text, int maxLength) {
    if (text.length <= maxLength) return text.length;
    final searchRange = text.substring(0, maxLength);
    final lastDoubleNewline = searchRange.lastIndexOf('\n\n');
    if (lastDoubleNewline > maxLength ~/ 2) return lastDoubleNewline;
    final lastSingleNewline = searchRange.lastIndexOf('\n');
    if (lastSingleNewline > maxLength ~/ 2) return lastSingleNewline;
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

      final channelNote = formattedChat.isNotEmpty ? ' (Kanalınıza test mesajı gönderildi)' : '';
      return {
        'success': true,
        'message': 'Bağlantı başarılı! Bot: @$botName$channelNote',
      };
    } catch (e) {
      return {'success': false, 'message': 'Telegram Hatası: ${_extractTelegramError(e)}'};
    }
  }

  /// Facebook Sayfa bağlantısını ve erişim yetkisini test eder
  Future<Map<String, dynamic>> testFacebook(String pageId, String pageAccessToken) async {
    try {
      final cleanId = pageId.trim();
      final cleanToken = pageAccessToken.trim();

      if (cleanId.isEmpty || cleanToken.isEmpty) {
        return {'success': false, 'message': 'Facebook Sayfa ID ve Erişim Jetonu boş olamaz.'};
      }

      final res = await _dio.get(
        'https://graph.facebook.com/v19.0/$cleanId',
        queryParameters: {
          'fields': 'id,name,link',
          'access_token': cleanToken,
        },
      );

      if (res.statusCode == 200 && res.data['name'] != null) {
        final pageName = res.data['name'];
        return {
          'success': true,
          'message': 'Facebook bağlantısı başarılı! Sayfa: "$pageName"',
        };
      }

      return {'success': false, 'message': 'Facebook sayfasına erişilemedi.'};
    } catch (e) {
      return {'success': false, 'message': 'Facebook Hatası: ${_extractFacebookError(e)}'};
    }
  }
}
