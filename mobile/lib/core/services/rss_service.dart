import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

class RssItemData {
  final String title;
  final String link;
  final String content;
  final String? imageUrl;

  RssItemData({
    required this.title,
    required this.link,
    required this.content,
    this.imageUrl,
  });
}

class RssService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/rss+xml, application/xml, text/xml, */*',
      },
    ),
  );

  /// Belirtilen RSS URL'inden haberleri çeker ve temizleyip listeler
  Future<List<RssItemData>> fetchFeed(String url) async {
    try {
      final response = await _dio.get(url);
      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final document = XmlDocument.parse(response.data.toString());
      final items = document.findAllElements('item');
      final List<RssItemData> list = [];

      for (var item in items) {
        final title = item.findElements('title').isNotEmpty
            ? item.findElements('title').first.innerText.trim()
            : '';

        final link = item.findElements('link').isNotEmpty
            ? item.findElements('link').first.innerText.trim()
            : (item.findElements('guid').isNotEmpty
                ? item.findElements('guid').first.innerText.trim()
                : '');

        var rawContent = '';
        if (item.findElements('description').isNotEmpty) {
          rawContent = item.findElements('description').first.innerText;
        } else if (item.findElements('content:encoded').isNotEmpty) {
          rawContent = item.findElements('content:encoded').first.innerText;
        }

        // Görsel URL'sini çıkart
        String? imageUrl;

        // 1. enclosure tag kontrolü
        final enclosures = item.findElements('enclosure');
        if (enclosures.isNotEmpty) {
          final urlAttr = enclosures.first.getAttribute('url');
          if (urlAttr != null && (urlAttr.endsWith('.jpg') || urlAttr.endsWith('.png') || urlAttr.endsWith('.webp') || urlAttr.contains('image'))) {
            imageUrl = urlAttr;
          }
        }

        // 2. media:content veya media:thumbnail kontrolü
        if (imageUrl == null) {
          final mediaContent = item.findAllElements('media:content');
          if (mediaContent.isNotEmpty) {
            imageUrl = mediaContent.first.getAttribute('url');
          }
          if (imageUrl == null) {
            final mediaThumbnail = item.findAllElements('media:thumbnail');
            if (mediaThumbnail.isNotEmpty) {
              imageUrl = mediaThumbnail.first.getAttribute('url');
            }
          }
        }

        // 3. İçerik içindeki <img src="..."> kontrolü
        if (imageUrl == null && rawContent.contains('<img')) {
          final regExp = RegExp(r'<img[^>]+src="([^">]+)"');
          final match = regExp.firstMatch(rawContent);
          if (match != null && match.groupCount >= 1) {
            imageUrl = match.group(1);
          }
        }

        // HTML etiketlerini metinden temizle
        final cleanContent = rawContent
            .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (title.isNotEmpty && link.isNotEmpty) {
          list.add(
            RssItemData(
              title: title,
              link: link,
              content: cleanContent,
              imageUrl: imageUrl,
            ),
          );
        }
      }

      return list;
    } catch (e) {
      print('[RssService Error] $url çekilemedi: $e');
      return [];
    }
  }
}
