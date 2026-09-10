import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart';
import '../database/database_helper.dart';
import 'ai_service.dart';

class ScrapedArticle {
  final String title;
  final String link;
  final String content;
  final String? imageUrl;

  ScrapedArticle({
    required this.title,
    required this.link,
    required this.content,
    this.imageUrl,
  });
}

/// Otonom ve Kendi Kendine Öğrenen Evrensel Web Kazıyıcı Motoru
class UniversalWebScraperService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final AiService _aiService = AiService();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: true,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    ),
  );

  /// Herhangi bir web sitesinden (Örn: kokludegisim.net/haberler, site.com vb.) veya RSS akışından haberleri çeker
  Future<List<ScrapedArticle>> scrapeFromUrl(String url) async {
    try {
      var cleanUrl = url.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }

      final uri = Uri.parse(cleanUrl);
      final domain = uri.host.toLowerCase();

      final response = await _dio.get(cleanUrl);
      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final rawData = response.data.toString().trim();

      // 1. Durum: XML / RSS akışı ise doğrudan ayrıştır
      if (rawData.startsWith('<?xml') || rawData.contains('<rss') || rawData.contains('<feed')) {
        return _parseRssXml(rawData, cleanUrl);
      }

      // 2. Durum: HTML sayfası
      final document = html_parser.parse(rawData);

      // 2.A: Sayfada gizli bir RSS akışı var mı? (<link rel="alternate" type="application/rss+xml">)
      final rssLinkEl = document.querySelector('link[type*="rss+xml"], link[type*="atom+xml"]');
      if (rssLinkEl != null) {
        final rssHref = rssLinkEl.attributes['href'];
        if (rssHref != null && rssHref.isNotEmpty) {
          final fullRssUrl = Uri.parse(cleanUrl).resolve(rssHref).toString();
          try {
            final rssRes = await _dio.get(fullRssUrl);
            if (rssRes.statusCode == 200 && rssRes.data != null) {
              final rssArticles = _parseRssXml(rssRes.data.toString(), fullRssUrl);
              if (rssArticles.isNotEmpty) return rssArticles;
            }
          } catch (_) {}
        }
      }

      // 2.B: Sayfa doğrudan tek bir haberin detay sayfası mı? (og:title / og:description)
      final ogTitle = document.querySelector('meta[property="og:title"], meta[name="twitter:title"]')?.attributes['content'];
      final ogDesc = document.querySelector('meta[property="og:description"], meta[name="twitter:description"]')?.attributes['content'];
      final ogImage = document.querySelector('meta[property="og:image"], meta[name="twitter:image"], link[rel="image_src"]')?.attributes['content'];

      final articleBodyEl = document.querySelector('article, [class*="article-body"], [class*="news-content"], [class*="haber-detay"], [itemprop="articleBody"]');

      // Eğer sayfa tekil bir haber detay sayfasıysa:
      if (ogTitle != null && ogTitle.trim().isNotEmpty && (ogDesc != null && ogDesc.trim().length > 50 || articleBodyEl != null)) {
        String fullArticleText = ogDesc ?? '';
        if (articleBodyEl != null) {
          final pTexts = articleBodyEl.querySelectorAll('p').map((p) => p.text.trim()).where((t) => t.length > 25);
          if (pTexts.isNotEmpty) {
            fullArticleText = pTexts.join('\n\n');
          }
        }

        return [
          ScrapedArticle(
            title: ogTitle.trim(),
            link: cleanUrl,
            content: fullArticleText,
            imageUrl: _resolveImageUrl(ogImage, cleanUrl),
          ),
        ];
      }

      // 2.C: Liste sayfası - Çok Aşamalı Otonom Keşif ve Kendi Kendine Öğrenme

      // Adım 1: Bu domain için geçmişte öğrenilmiş bir kural var mı?
      final learnedRule = await _db.getLearnedRule(domain);
      if (learnedRule != null) {
        final cardSelector = learnedRule['card_selector'] as String?;
        if (cardSelector != null && cardSelector.isNotEmpty) {
          final learnedArticles = _extractUsingLearnedRule(document, cleanUrl, cardSelector);
          if (learnedArticles.length >= 2) {
            return await _enrichArticlesWithFullContentAndImages(learnedArticles, cleanUrl);
          }
        }
      }

      // Adım 2: Evrensel Semantik DOM Yoğunluk Analizi (Next.js, React, HTML5 uyumlu)
      var articles = _extractArticlesFromListingPage(document, cleanUrl);
      if (articles.length >= 2) {
        return await _enrichArticlesWithFullContentAndImages(articles, cleanUrl);
      }

      // Adım 3: JSON-LD & Schema.org Yapılandırılmış Veri Analizi
      articles = _extractFromJsonLd(document, cleanUrl);
      if (articles.length >= 2) {
        return await _enrichArticlesWithFullContentAndImages(articles, cleanUrl);
      }

      // Adım 4: OTONOM YAPAY ZEKA KEŞFİ VE KURAL ÖĞRENME (AI Self-Learning)
      // Heuristikler yetersiz kaldıysa, Yapay Zeka sayfayı analiz eder ve kuralı öğrenir!
      print('[UniversalWebScraper] Standart heuristikler yetersiz kaldı, Gemini Otonom Analizci Devreye Giriyor: $cleanUrl');
      final condensedDom = _buildCondensedDomForAi(document, cleanUrl);

      final aiDiscoveryResult = await _aiService.discoverNewsAndLearnPattern(
        domain: domain,
        listingUrl: cleanUrl,
        condensedHtml: condensedDom,
      );

      if (aiDiscoveryResult != null && aiDiscoveryResult['articles'] is List) {
        final rawArticles = aiDiscoveryResult['articles'] as List;
        final List<ScrapedArticle> aiExtracted = [];

        for (var item in rawArticles) {
          if (item is Map) {
            final t = item['title']?.toString().trim() ?? '';
            final l = item['link']?.toString().trim() ?? '';
            final s = item['summary']?.toString().trim() ?? t;
            final img = item['imageUrl']?.toString().trim();

            if (t.isNotEmpty && l.isNotEmpty) {
              aiExtracted.add(
                ScrapedArticle(
                  title: t,
                  link: _resolveImageUrl(l, cleanUrl) ?? l,
                  content: s,
                  imageUrl: _resolveImageUrl(img, cleanUrl),
                ),
              );
            }
          }
        }

        // Eğer yapay zeka sitedeki kural desenini çıkardıysa veritabanına kaydet
        if (aiDiscoveryResult['learnedPattern'] is Map) {
          final patternMap = aiDiscoveryResult['learnedPattern'] as Map;
          final cardSelector = patternMap['cardSelector']?.toString();
          final urlPattern = patternMap['urlPattern']?.toString();

          if (cardSelector != null && cardSelector.isNotEmpty) {
            await _db.saveLearnedRule(
              domain: domain,
              cardSelector: cardSelector,
              urlPattern: urlPattern,
            );
            print('[UniversalWebScraper] AI "$domain" sitesinin kuralını başarıyla öğrendi ve veritabanına kaydetti!');
          }
        }

        if (aiExtracted.isNotEmpty) {
          return await _enrichArticlesWithFullContentAndImages(aiExtracted, cleanUrl);
        }
      }

      return articles;
    } catch (e) {
      print('[UniversalWebScraper Error] $url: $e');
      return [];
    }
  }

  /// Öğrenilmiş kuralı kullanarak haber kartlarını ayıklar
  List<ScrapedArticle> _extractUsingLearnedRule(
      dom.Document document, String baseUrl, String cardSelector) {
    final List<ScrapedArticle> articles = [];
    final seenLinks = <String>{};

    try {
      final elements = document.querySelectorAll(cardSelector);
      for (var el in elements) {
        final aTag = el.localName == 'a' ? el : el.querySelector('a');
        if (aTag == null) continue;

        final href = aTag.attributes['href'];
        if (href == null || href.isEmpty || href.startsWith('javascript:')) continue;

        final fullLink = Uri.parse(baseUrl).resolve(href).toString();
        if (seenLinks.contains(fullLink)) continue;

        var title = '';
        final heading = el.querySelector('h1, h2, h3, h4, h5, h6');
        if (heading != null && heading.text.trim().length >= 10) {
          title = heading.text.trim();
        } else if (aTag.text.trim().length >= 10) {
          title = aTag.text.trim();
        }
        if (title.length < 10) continue;

        var content = '';
        final p = el.querySelector('p');
        if (p != null && p.text.trim().length >= 15) {
          content = p.text.trim();
        } else {
          content = title;
        }

        final imageUrl = _extractBestImageFromElement(el, baseUrl);
        seenLinks.add(fullLink);

        articles.add(
          ScrapedArticle(
            title: title,
            link: fullLink,
            content: content,
            imageUrl: imageUrl,
          ),
        );

        if (articles.length >= 25) break;
      }
    } catch (e) {
      print('[LearnedRule Extraction Error]: $e');
    }

    return articles;
  }

  /// JSON-LD ve Schema.org standart yapılandırılmış verilerinden haberleri çıkarır
  List<ScrapedArticle> _extractFromJsonLd(dom.Document document, String baseUrl) {
    final List<ScrapedArticle> articles = [];
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');

    for (var s in scripts) {
      try {
        final raw = s.text.trim();
        if (raw.isEmpty) continue;
        final decoded = jsonDecode(raw);

        List<dynamic> items = [];
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['@graph'] is List) {
            items = decoded['@graph'] as List;
          } else if (decoded['itemListElement'] is List) {
            items = decoded['itemListElement'] as List;
          } else {
            items = [decoded];
          }
        }

        for (var item in items) {
          if (item is! Map<String, dynamic>) continue;
          if (item.containsKey('url') &&
              (item.containsKey('name') || item.containsKey('headline'))) {
            final title =
                item['headline']?.toString() ?? item['name']?.toString() ?? '';
            final link = item['url']?.toString() ?? '';
            String? image;
            if (item['image'] is String) {
              image = item['image'];
            } else if (item['image'] is Map) {
              image = item['image']['url']?.toString();
            } else if (item['image'] is List && (item['image'] as List).isNotEmpty) {
              image = (item['image'] as List).first.toString();
            }

            if (title.length >= 10 && link.isNotEmpty) {
              articles.add(
                ScrapedArticle(
                  title: title.trim(),
                  link: _resolveImageUrl(link, baseUrl) ?? link,
                  content: item['description']?.toString() ?? title.trim(),
                  imageUrl: _resolveImageUrl(image, baseUrl),
                ),
              );
            }
          }
        }
      } catch (_) {}
    }
    return articles;
  }

  /// Yapay zeka analizi için sayfa DOM'unun hafifleştirilmiş şablonunu üretir
  String _buildCondensedDomForAi(dom.Document document, String baseUrl) {
    final sb = StringBuffer();
    final pageTitle = document.querySelector('title')?.text.trim() ?? '';
    sb.writeln('<title>$pageTitle</title>');

    final anchors = document.querySelectorAll('a');
    int count = 0;

    for (var a in anchors) {
      final href = a.attributes['href'];
      if (href == null ||
          href.isEmpty ||
          href == '#' ||
          href.startsWith('javascript:')) {
        continue;
      }

      final text = a.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      final hasImg = a.querySelector('img') != null;
      final hasHeading = a.querySelector('h1, h2, h3, h4, h5, h6') != null;

      if (text.length < 15 && !hasImg && !hasHeading) continue;

      final lowerHref = href.toLowerCase();
      if (lowerHref.contains('login') ||
          lowerHref.contains('signup') ||
          lowerHref.contains('contact') ||
          lowerHref.contains('iletisim') ||
          lowerHref.contains('hakkimizda') ||
          lowerHref.contains('gizlilik') ||
          lowerHref.contains('terms')) {
        continue;
      }

      sb.write('<a href="$href"');
      if (a.className.isNotEmpty) {
        sb.write(' class="${a.className}"');
      }
      sb.writeln('>');

      final img = a.querySelector('img');
      if (img != null) {
        final src = img.attributes['src'] ??
            img.attributes['data-src'] ??
            img.attributes['data-original'];
        if (src != null && src.isNotEmpty) {
          sb.writeln('  <img src="$src" />');
        }
      }

      final heading = a.querySelector('h1, h2, h3, h4, h5, h6');
      if (heading != null) {
        sb.writeln(
            '  <${heading.localName}>${heading.text.replaceAll(RegExp(r'\s+'), ' ').trim()}</${heading.localName}>');
      } else if (text.isNotEmpty) {
        sb.writeln('  <span>$text</span>');
      }

      final p = a.querySelector('p');
      if (p != null && p.text.trim().isNotEmpty) {
        sb.writeln('  <p>${p.text.replaceAll(RegExp(r'\s+'), ' ').trim()}</p>');
      }

      sb.writeln('</a>');
      count++;
      if (count >= 50) break;
    }

    return sb.toString();
  }

  /// Her haberin detay sayfasına giderek hem TAM orijinal metni (tüm paragrafları)
  /// hem de yüksek çözünürlüklü kapak görselini (og:image) eksiksiz çeker
  Future<List<ScrapedArticle>> _enrichArticlesWithFullContentAndImages(
      List<ScrapedArticle> articles, String baseUrl) async {
    final List<ScrapedArticle> enriched = [];

    for (var art in articles) {
      // Eğer tekil bir haber sayfası zaten tam metinle geldiyse (uzunluk > 350 karakter)
      // ve görseli varsa tekrar detay sayfasına gitmeye gerek yok
      if (art.content.length > 350 && art.imageUrl != null && art.imageUrl!.isNotEmpty) {
        enriched.add(art);
        continue;
      }

      try {
        final detailRes = await _dio.get(
          art.link,
          options: Options(
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

        if (detailRes.statusCode == 200 && detailRes.data != null) {
          final detailDoc = html_parser.parse(detailRes.data.toString());

          // 1. Kapak görseli zenginleştirme (og:image en yüksek çözünürlüktür)
          final ogImage = detailDoc
              .querySelector('meta[property="og:image"], meta[name="twitter:image"]')
              ?.attributes['content'];
          final resolvedImage = _resolveImageUrl(ogImage, art.link) ?? art.imageUrl;

          // 2. Tam Orijinal Metin Zenginleştirme
          // Script, style, header, footer, nav etiketlerini temizle
          for (var el in detailDoc.querySelectorAll('script, style, noscript, header, footer, nav, aside, .ad, .ads, .sidebar')) {
            el.remove();
          }

          // Öncelikli makale gövdesi seçicileri
          final contentContainer = detailDoc.querySelector(
              'article, [itemprop="articleBody"], [class*="article-content"], [class*="article-body"], [class*="news-content"], [class*="news-detail"], [class*="haber-metni"], [class*="haber-icerik"], [class*="detay-icerik"], [class*="entry-content"], [class*="post-content"], [class*="prose"], main');

          final searchRoot = contentContainer ?? detailDoc.body;
          String fullContent = art.content;

          if (searchRoot != null) {
            final pElements = searchRoot.querySelectorAll('p');
            final validParagraphs = <String>[];

            for (var p in pElements) {
              final text = p.text
                  .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();

              // Çok kısa veya reklam/künye etiketlerini filtrele
              if (text.length >= 25 &&
                  !text.startsWith('Fotoğraf:') &&
                  !text.startsWith('Kaynak:') &&
                  !text.contains('Tüm hakları saklıdır')) {
                validParagraphs.add(text);
              }
            }

            if (validParagraphs.isNotEmpty) {
              fullContent = validParagraphs.join('\n\n');
            }
          }

          // Eğer p etiketleri bulunamadıysa ama og:description daha uzunsa onu kullan
          if (fullContent.length <= art.content.length) {
            final ogDesc = detailDoc
                .querySelector('meta[property="og:description"], meta[name="twitter:description"]')
                ?.attributes['content']
                ?.trim();
            if (ogDesc != null && ogDesc.length > fullContent.length) {
              fullContent = ogDesc;
            }
          }

          enriched.add(
            ScrapedArticle(
              title: art.title,
              link: art.link,
              content: fullContent,
              imageUrl: resolvedImage,
            ),
          );
          continue;
        }
      } catch (e) {
        print('[UniversalWebScraper] Detay sayfası zenginleştirme hatası (${art.link}): $e');
      }

      enriched.add(art);
    }

    return enriched;
  }

  /// Liste sayfasındaki (Örn: kokludegisim.net/haberler) tüm haber kartlarını, başlıklarını ve görsellerini çeker
  List<ScrapedArticle> _extractArticlesFromListingPage(dom.Document document, String baseUrl) {
    final List<ScrapedArticle> articles = [];
    final seenLinks = <String>{};

    final allLinks = document.querySelectorAll('a');

    for (var a in allLinks) {
      final href = a.attributes['href'];
      if (href == null || href.isEmpty || href == '#' || href.startsWith('javascript:') || href.startsWith('tel:') || href.startsWith('mailto:')) {
        continue;
      }

      // Linki tam web adresine çevir
      String fullLink;
      try {
        fullLink = Uri.parse(baseUrl).resolve(href).toString();
      } catch (_) {
        continue;
      }

      // Kendi kendine dönen ana kategori linklerini filtrele
      if (fullLink == baseUrl || fullLink == '$baseUrl/' || fullLink.endsWith('/haberler') || fullLink.endsWith('/haberler/')) {
        continue;
      }
      if (seenLinks.contains(fullLink)) continue;

      // 1. Başlık tespiti: <a> içindeki h1-h6 veya başlık class'ları
      var title = '';
      final heading = a.querySelector('h1, h2, h3, h4, h5, h6, [class*="title"], [class*="baslik"]');
      if (heading != null && heading.text.trim().length >= 10) {
        title = heading.text.trim();
      } else if (a.text.trim().length >= 15) {
        title = a.text.trim();
      }

      // Eğer <a> içinde başlık yoksa ebeveynine (parent) bak
      if (title.length < 10 && a.parent != null) {
        final parentHeading = a.parent!.querySelector('h1, h2, h3, h4, h5, h6');
        if (parentHeading != null && parentHeading.text.trim().length >= 10) {
          title = parentHeading.text.trim();
        }
      }

      // Başlık hala bulunamadıysa veya 10 karakterden kısaysa bu geçerli bir haber linki değildir
      if (title.length < 10) continue;

      // 2. Özet metni tespiti: <a> içindeki <p> veya ebeveynindeki <p>
      var content = '';
      final pTag = a.querySelector('p') ?? a.parent?.querySelector('p');
      if (pTag != null && pTag.text.trim().length > 10) {
        content = pTag.text.trim();
      } else {
        content = title;
      }

      // 3. Görsel tespiti: <a> içindeki <img> veya ebeveynindeki <img>
      String? imageUrl = _extractBestImageFromElement(a, baseUrl);
      if (imageUrl == null && a.parent != null) {
        imageUrl = _extractBestImageFromElement(a.parent!, baseUrl);
      }

      seenLinks.add(fullLink);

      articles.add(
        ScrapedArticle(
          title: title,
          link: fullLink,
          content: content,
          imageUrl: imageUrl,
        ),
      );

      if (articles.length >= 25) break; // Her sayfadan en güncel 25 haberi topla
    }

    return articles;
  }

  /// Tüm modern resim ve lazy-load etiketlerinden gerçek görsel linkini ayıklar
  String? _extractBestImageFromElement(dom.Element element, String baseUrl) {
    // 1. <img> etiketlerini incele
    final imgElements = element.querySelectorAll('img');
    for (var img in imgElements) {
      final possibleAttributes = [
        'src',
        'data-src',
        'data-original',
        'data-lazy-src',
        'data-lazy',
        'data-img-url',
        'data-actualsrc',
        'data-full-src',
        'data-hi-res-src',
      ];

      for (var attr in possibleAttributes) {
        final val = img.attributes[attr];
        if (val != null && _isValidImageUrl(val)) {
          return _resolveImageUrl(val, baseUrl);
        }
      }

      // srcset kontrolü
      final srcset = img.attributes['srcset'] ?? img.attributes['data-srcset'];
      if (srcset != null && srcset.isNotEmpty) {
        final parts = srcset.split(',');
        if (parts.isNotEmpty) {
          final bestSrc = parts.last.trim().split(' ').first;
          if (_isValidImageUrl(bestSrc)) {
            return _resolveImageUrl(bestSrc, baseUrl);
          }
        }
      }
    }

    // 2. <picture> <source> kontrolü
    final sources = element.querySelectorAll('picture source');
    for (var s in sources) {
      final srcset = s.attributes['srcset'] ?? s.attributes['data-srcset'];
      if (srcset != null && srcset.isNotEmpty) {
        final firstUrl = srcset.split(',').last.trim().split(' ').first;
        if (_isValidImageUrl(firstUrl)) {
          return _resolveImageUrl(firstUrl, baseUrl);
        }
      }
    }

    // 3. style="background-image: url(...)" kontrolü
    final styledElements = element.querySelectorAll('[style*="background"]');
    for (var el in styledElements) {
      final style = el.attributes['style'] ?? '';
      final match = RegExp(r'url\((.*?)\)').firstMatch(style);
      if (match != null && match.groupCount >= 1) {
        final rawUrl = match.group(1)?.replaceAll("'", "").replaceAll('"', "").trim();
        if (rawUrl != null && rawUrl.isNotEmpty && _isValidImageUrl(rawUrl)) {
          return _resolveImageUrl(rawUrl, baseUrl);
        }
      }
    }

    return null;
  }

  /// Geçerli bir resim linki mi? (Placeholder veya svg ikonları filtreler)
  bool _isValidImageUrl(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.isEmpty) return false;
    if (lower.startsWith('data:image/svg') ||
        lower.startsWith('data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7')) {
      return false; // 1x1 şeffaf placeholder
    }
    if (lower.contains('placeholder') || lower.contains('blank.gif') || lower.contains('loading.gif')) {
      return false;
    }
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.avif') ||
        lower.contains('image') ||
        lower.contains('img') ||
        lower.contains('upload') ||
        lower.contains('api.');
  }

  /// Göreceli linkleri tam web adresine dönüştürür
  String? _resolveImageUrl(String? rawUrl, String baseUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    var clean = rawUrl.trim();

    if (clean.startsWith('//')) {
      clean = 'https:$clean';
    }

    try {
      return Uri.parse(baseUrl).resolve(clean).toString();
    } catch (_) {
      return clean;
    }
  }

  /// XML / RSS Akışını ayrıştırır
  List<ScrapedArticle> _parseRssXml(String xmlString, String feedUrl) {
    final List<ScrapedArticle> list = [];
    try {
      final document = XmlDocument.parse(xmlString);
      final items = document.findAllElements('item');

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

        String? imageUrl;
        final enclosures = item.findElements('enclosure');
        if (enclosures.isNotEmpty) {
          imageUrl = enclosures.first.getAttribute('url');
        }
        if (imageUrl == null) {
          final mediaContent = item.findAllElements('media:content');
          if (mediaContent.isNotEmpty) {
            imageUrl = mediaContent.first.getAttribute('url');
          }
        }
        if (imageUrl == null) {
          final mediaThumbnail = item.findAllElements('media:thumbnail');
          if (mediaThumbnail.isNotEmpty) {
            imageUrl = mediaThumbnail.first.getAttribute('url');
          }
        }
        if (imageUrl == null && rawContent.contains('<img')) {
          final match = RegExp(r'<img[^>]+src="([^">]+)"').firstMatch(rawContent);
          if (match != null && match.groupCount >= 1) {
            imageUrl = match.group(1);
          }
        }

        final cleanContent = rawContent
            .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (title.isNotEmpty && link.isNotEmpty) {
          list.add(
            ScrapedArticle(
              title: title,
              link: link,
              content: cleanContent.isNotEmpty ? cleanContent : title,
              imageUrl: _resolveImageUrl(imageUrl, feedUrl),
            ),
          );
        }
      }
    } catch (e) {
      print('[Rss Parse Error] $e');
    }
    return list;
  }
}
