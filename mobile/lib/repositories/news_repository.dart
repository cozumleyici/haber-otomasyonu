import '../core/database/database_helper.dart';
import '../core/services/web_scraper_service.dart';
import '../core/services/ai_service.dart';
import '../core/services/publisher_service.dart';
import '../models/news_draft.dart';

class NewsRepository {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final UniversalWebScraperService scraperService = UniversalWebScraperService();
  final AiService aiService = AiService();
  final PublisherService publisherService = PublisherService();

  /// Bekleyen tüm taslak haberleri yerel veritabanından getirir
  Future<List<NewsDraft>> fetchPendingNews() async {
    final rows = await dbHelper.getPendingDrafts();
    return rows.map((r) => NewsDraft.fromJson(r)).toList();
  }

  /// Aktif kaynaklardan (herhangi bir web sitesi veya RSS) haberleri çeker ve AI ile işler
  Stream<String> scanAndProcessNews() async* {
    yield 'Haber kaynakları taranıyor...';
    final sources = await dbHelper.getActiveSources();
    if (sources.isEmpty) {
      yield 'Aktif haber kaynağı bulunamadı. Lütfen kaynak ekleyin.';
      return;
    }

    int totalNewArticles = 0;

    for (var source in sources) {
      final sourceName = source['name'] as String;
      final sourceUrl = source['url'] as String;

      yield '$sourceName sitesinden haberler alınıyor...';
      final articles = await scraperService.scrapeFromUrl(sourceUrl);

      for (var item in articles) {
        // Zaten daha önce çekilmiş mi kontrol et
        final isScraped = await dbHelper.isUrlAlreadyScraped(item.link);
        if (isScraped) continue;

        yield 'Yapay zeka düzenliyor: ${item.title.length > 25 ? item.title.substring(0, 25) + '...' : item.title}';

        // Gemini ile yeniden yaz ve özetle (kullanıcı hafızasından öğrenerek)
        final aiResult = await aiService.rewriteNews(
          rawTitle: item.title,
          rawContent: item.content,
        );

        final now = DateTime.now().toIso8601String();
        final draftId = DateTime.now().millisecondsSinceEpoch.toString();

        await dbHelper.insertDraft({
          'id': draftId,
          'source_type': 'web',
          'source_url': item.link,
          'original_title': item.title,
          'original_content': item.content,
          'ai_title': aiResult.title,
          'ai_content': aiResult.content,
          'image_url': item.imageUrl,
          'status': 'PENDING',
          'target_platforms': '["telegram"]',
          'created_at': now,
          'updated_at': now,
        });

        totalNewArticles++;
      }
    }

    if (totalNewArticles > 0) {
      yield '$totalNewArticles yeni haber hazırlandı ve incelemenize sunuldu!';
    } else {
      yield 'Tüm siteler güncel, yeni haber bulunamadı.';
    }
  }

  /// Kullanıcının yapıştırdığı tek bir haber linkini anında çekip AI ile özetler
  Future<void> scrapeSingleUrl(String url) async {
    final articles = await scraperService.scrapeFromUrl(url);
    if (articles.isEmpty) {
      throw Exception('Sayfadan haber içeriği alınamadı. Lütfen linki kontrol edin.');
    }

    final item = articles.first;
    final aiResult = await aiService.rewriteNews(
      rawTitle: item.title,
      rawContent: item.content,
    );

    final now = DateTime.now().toIso8601String();
    final draftId = DateTime.now().millisecondsSinceEpoch.toString();

    await dbHelper.insertDraft({
      'id': draftId,
      'source_type': 'custom_link',
      'source_url': item.link,
      'original_title': item.title,
      'original_content': item.content,
      'ai_title': aiResult.title,
      'ai_content': aiResult.content,
      'image_url': item.imageUrl,
      'status': 'PENDING',
      'target_platforms': '["telegram"]',
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Editörün onay/ret kararını işler
  Future<Map<String, dynamic>> submitDecision({
    required String draftId,
    required String action, // 'approve' veya 'reject'
    required String originalTitle,
    required String originalContent,
    required String aiTitle,
    required String aiContent,
    required String finalTitle,
    required String finalContent,
    String? imageUrl,
    List<String>? targetPlatforms,
  }) async {
    if (action == 'reject') {
      await dbHelper.updateDraftStatus(draftId, 'REJECTED');
      return {'success': true, 'message': 'Haber taslağı reddedildi.'};
    }

    // ON ONAY (APPROVE):
    // 1. Kullanıcının yaptığı düzeltmeleri AI'nin Öğrenmesi için kaydet
    await dbHelper.recordUserEdit(
      originalTitle: originalTitle,
      aiTitle: aiTitle,
      userEditedTitle: finalTitle,
      originalContent: originalContent,
      aiContent: aiContent,
      userEditedContent: finalContent,
    );

    // 2. Doğrudan Telegram'a yayınla
    final pubResult = await publisherService.publishNews(
      finalTitle: finalTitle,
      finalContent: finalContent,
      imageUrl: imageUrl,
      targetPlatforms: targetPlatforms,
    );

    if (pubResult.success) {
      await dbHelper.updateDraftContent(
        id: draftId,
        title: finalTitle,
        content: finalContent,
        status: 'PUBLISHED',
      );
      return {'success': true, 'message': pubResult.message};
    } else {
      throw Exception(pubResult.message);
    }
  }

  /// Bekleyen tüm taslakları siler
  Future<void> deleteAllPendingDrafts() async {
    await dbHelper.deleteAllPendingDrafts();
  }

  /// Seçilen taslakları siler
  Future<void> deleteSelectedDrafts(List<String> ids) async {
    await dbHelper.deleteDraftsByIds(ids);
  }
}
