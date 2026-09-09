import 'dart:convert';
import 'package:dio/dio.dart';
import '../database/database_helper.dart';

class AiRewriteResult {
  final String title;
  final String content;

  AiRewriteResult({required this.title, required this.content});
}

class AiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Haberi kullanıcının talimatlarına ve geçmişte öğrendiği editör tarzına göre yeniden yazar
  Future<AiRewriteResult> rewriteNews({
    required String rawTitle,
    required String rawContent,
  }) async {
    final settings = await DatabaseHelper.instance.getAllSettings();
    final provider = settings['ai_provider'] ?? 'gemini';
    final customPrompt = settings['ai_custom_instructions'] ??
        'Sen profesyonel bir haber editörüsün. Haberi tarafsız, dikkat çekici 2 paragraflık bir özet haline getir. Yüksek CTR başlık üret.';

    // 1. Editörün geçmiş düzeltmelerini (Few-Shot Learning) veritabanından çek
    final learnedEdits = await DatabaseHelper.instance.getRecentLearnedEdits(limit: 3);

    var fewShotInstruction = '';
    if (learnedEdits.isNotEmpty) {
      fewShotInstruction = '\n\n--- DİKKAT: EDİTÖRÜN GEÇMİŞ DÜZELTME VE ÜSLUP TERCİHLERİ ---\n';
      fewShotInstruction += 'Editör geçmiş haberlerde AI önerilerini şu şekilde düzeltti ve onayladı. Yeni haberi yazarken editörün bu üslubunu ve başlık atma tarzını MUTLAKA taklit et:\n';

      for (int i = 0; i < learnedEdits.length; i++) {
        final edit = learnedEdits[i];
        fewShotInstruction += '''
[Örnek ${i + 1}]
- AI'nin Önerdiği Başlık: "${edit['ai_title']}"
  -> Editörün Düzelttiği ve İstediği Başlık: "${edit['user_edited_title']}"
- Editörün Beğendiği Metin Tarzı: "${edit['user_edited_content']}"
''';
      }
      fewShotInstruction += '--- EDİTÖR TERCİHLERİ SONU ---\n';
    }

    final fullSystemPrompt = '''
$customPrompt
$fewShotInstruction

SADECE geçerli bir JSON objesi formatında şu yapıda cevap ver:
{
  "title": "Yeniden yazılmış çarpıcı başlık",
  "content": "Yeniden yazılmış 2 paragraflık akıcı metin"
}
''';

    if (provider == 'gemini') {
      return await _rewriteWithGemini(
        apiKey: settings['gemini_api_key'] ?? '',
        model: settings['gemini_model'] ?? 'gemini-1.5-flash',
        systemPrompt: fullSystemPrompt,
        rawTitle: rawTitle,
        rawContent: rawContent,
      );
    } else {
      return await _rewriteWithOpenAi(
        apiKey: settings['openai_api_key'] ?? '',
        systemPrompt: fullSystemPrompt,
        rawTitle: rawTitle,
        rawContent: rawContent,
      );
    }
  }

  /// Google Gemini API Entegrasyonu (Ücretsiz API Key ile çalışır)
  Future<AiRewriteResult> _rewriteWithGemini({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String rawTitle,
    required String rawContent,
  }) async {
    if (apiKey.isEmpty) {
      print('[AiService] Gemini API anahtarı girilmemiş. Orijinal başlık ve içerik kullanılıyor.');
      return AiRewriteResult(title: rawTitle, content: rawContent);
    }

    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    final userMessage = '''
Orijinal Haber Başlığı: $rawTitle

Orijinal Haber İçeriği:
$rawContent
''';

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$systemPrompt\n\n$userMessage'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'responseMimeType': 'application/json',
      }
    };

    try {
      final response = await _dio.post(endpoint, data: payload);
      if (response.statusCode == 200) {
        final candidates = response.data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final contentParts = candidates.first['content']['parts'] as List;
          final text = contentParts.first['text'] as String;
          return _parseJsonResponse(text, rawTitle, rawContent);
        }
      }
      return AiRewriteResult(title: rawTitle, content: rawContent);
    } catch (e) {
      print('[AiService Gemini Error]: $e');
      return AiRewriteResult(title: rawTitle, content: rawContent);
    }
  }

  /// OpenAI API Entegrasyonu
  Future<AiRewriteResult> _rewriteWithOpenAi({
    required String apiKey,
    required String systemPrompt,
    required String rawTitle,
    required String rawContent,
  }) async {
    if (apiKey.isEmpty) {
      return AiRewriteResult(title: rawTitle, content: rawContent);
    }

    final payload = {
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': 'Başlık: $rawTitle\n\nİçerik:\n$rawContent'
        }
      ],
      'temperature': 0.4,
      'response_format': {'type': 'json_object'}
    };

    try {
      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
        data: payload,
      );

      if (response.statusCode == 200) {
        final text = response.data['choices'][0]['message']['content'] as String;
        return _parseJsonResponse(text, rawTitle, rawContent);
      }
      return AiRewriteResult(title: rawTitle, content: rawContent);
    } catch (e) {
      print('[AiService OpenAI Error]: $e');
      return AiRewriteResult(title: rawTitle, content: rawContent);
    }
  }

  /// JSON çıktısını güvenli bir şekilde ayrıştırır
  AiRewriteResult _parseJsonResponse(String rawText, String fallbackTitle, String fallbackContent) {
    try {
      var cleanJson = rawText.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
      return AiRewriteResult(
        title: decoded['title']?.toString() ?? fallbackTitle,
        content: decoded['content']?.toString() ?? fallbackContent,
      );
    } catch (e) {
      print('[AiService Parse Error]: $e. Raw: $rawText');
      return AiRewriteResult(title: fallbackTitle, content: fallbackContent);
    }
  }

  /// Otonom Kazıyıcı: Bilinmeyen veya yapısı karmaşık bir sitenin HTML yapısını analiz eder,
  /// haberleri çıkarır ve sitenin gelecekteki taramaları için kural desenini öğrenir.
  Future<Map<String, dynamic>?> discoverNewsAndLearnPattern({
    required String domain,
    required String listingUrl,
    required String condensedHtml,
  }) async {
    final settings = await DatabaseHelper.instance.getAllSettings();
    final apiKey = settings['gemini_api_key'] ?? '';
    final model = settings['gemini_model'] ?? 'gemini-1.5-flash';

    if (apiKey.isEmpty) {
      print('[AiService] Gemini API Key boş, otonom AI taraması yapılamadı.');
      return null;
    }

    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    final systemInstruction = '''
Sen dünya standartlarında bir Otonom Web Kazıyıcı (Autonomous Web Scraper AI) ve HTML/DOM Analizcisisin.
Görevin, sana verilen web sayfası özet DOM yapısını incelemek ve haber makalelerini tespit etmektir.

GÖREVLER:
1. Sayfadaki güncel haber kartlarını tespit et.
2. Her haber için:
   - "title": Haberin tam ve net başlığı
   - "link": Haberin tam URL'si (eğer göreceli "/haberler/..." ise "$listingUrl" tabanını kullanarak tam URL yap)
   - "imageUrl": Varsa kapak görselinin tam URL'si (yoksa null)
   - "summary": Varsa kısa özeti veya açıklaması (yoksa başlık ile aynı)
3. "learnedPattern" objesi içinde:
   - "cardSelector": Bu haber kartlarını seçebilecek CSS seçici veya class deseni (örn: "a[href*='/haberler/']", ".news-item", "article" vb.)
   - "urlPattern": Bu sitedeki haber bağlantılarını eşleştiren regex veya alt dize (örn: "/haberler/", "/detay/", "-\\d+\\.html")

SADECE geçerli bir JSON nesnesi döndür:
{
  "articles": [
    {
      "title": "...",
      "link": "https://...",
      "imageUrl": "https://...",
      "summary": "..."
    }
  ],
  "learnedPattern": {
    "cardSelector": "...",
    "urlPattern": "..."
  }
}
''';

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': '$systemInstruction\n\n'
                  'Web Sitesi Domain: $domain\n'
                  'Taranan Sayfa URL: $listingUrl\n\n'
                  'DOM ÖZETİ:\n$condensedHtml'
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'responseMimeType': 'application/json',
      }
    };

    try {
      final response = await _dio.post(endpoint, data: payload);
      if (response.statusCode == 200) {
        final candidates = response.data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final contentParts = candidates.first['content']['parts'] as List;
          final text = contentParts.first['text'] as String;

          var cleanJson = text.trim();
          if (cleanJson.startsWith('```json')) {
            cleanJson = cleanJson.substring(7);
          }
          if (cleanJson.endsWith('```')) {
            cleanJson = cleanJson.substring(0, cleanJson.length - 3);
          }
          cleanJson = cleanJson.trim();

          final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
          return decoded;
        }
      }
      return null;
    } catch (e) {
      print('[AiService Autonomous Scraper Error]: $e');
      return null;
    }
  }
}

