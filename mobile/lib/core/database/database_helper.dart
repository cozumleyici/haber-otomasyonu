import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('news_engine_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createDB(db, version);
        await _createLearnedRulesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createLearnedRulesTable(db);
        }
      },
    );
  }

  Future<void> _createLearnedRulesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS site_learned_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT UNIQUE NOT NULL,
        card_selector TEXT,
        url_pattern TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Haber Kaynakları Tablosu
    await db.execute('''
      CREATE TABLE news_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        url TEXT UNIQUE NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Taslak Haberler Tablosu
    await db.execute('''
      CREATE TABLE news_drafts (
        id TEXT PRIMARY KEY,
        source_type TEXT NOT NULL,
        source_url TEXT UNIQUE,
        original_title TEXT,
        original_content TEXT,
        ai_title TEXT,
        ai_content TEXT,
        image_url TEXT,
        status TEXT DEFAULT 'PENDING',
        target_platforms TEXT DEFAULT '["telegram", "wordpress"]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3. Editör Hafızası (AI'nin Kullanıcıdan Öğrenmesi için Örnekler Tablosu)
    await db.execute('''
      CREATE TABLE editorial_learning (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_title TEXT,
        ai_title TEXT,
        user_edited_title TEXT,
        original_content TEXT,
        ai_content TEXT,
        user_edited_content TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Uygulama ve Entegrasyon Ayarları Tablosu
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Varsayılan Ayarları Ekle
    await db.insert('app_settings', {
      'key': 'ai_provider',
      'value': 'gemini', // 'gemini' veya 'openai'
    });
    await db.insert('app_settings', {
      'key': 'gemini_api_key',
      'value': '',
    });
    await db.insert('app_settings', {
      'key': 'gemini_model',
      'value': 'gemini-1.5-flash',
    });
    await db.insert('app_settings', {
      'key': 'openai_api_key',
      'value': '',
    });
    await db.insert('app_settings', {
      'key': 'ai_custom_instructions',
      'value': 'Sen profesyonel bir haber editörüsün. Sana verilen haber metnini tarafsız, dikkat çekici, Türkçe ve akıcı 2 paragraflık bir özet haline getir. Tıklama oranı yüksek (yüksek CTR) ilgi çekici bir başlık üret. Metnin sonuna 2-3 adet popüler ilgili etiket (#gündem #haber gibi) ekle. SADECE geçerli JSON formatında şu yapıda cevap ver: {"title": "...", "content": "..."}',
    });
    await db.insert('app_settings', {
      'key': 'telegram_bot_token',
      'value': '',
    });
    await db.insert('app_settings', {
      'key': 'telegram_chat_id',
      'value': '',
    });
    await db.insert('app_settings', {
      'key': 'telegram_enabled',
      'value': 'true',
    });
    await db.insert('app_settings', {
      'key': 'wordpress_base_url',
      'value': '',
    });
    await db.insert('app_settings', {
      'key': 'wordpress_username',
      'value': '',
    });
    await db.insert('app_settings', {
      'key': 'wordpress_app_password',
      'value': '',
    });
    await db.insert('app_settings', {
      'key': 'wordpress_enabled',
      'value': 'true',
    });

    // Başlangıç Haber Kaynakları (Örnek Türk RSS Kaynakları)
    final now = DateTime.now().toIso8601String();
    await db.insert('news_sources', {
      'id': 'src-bbc-tr',
      'name': 'BBC Türkçe',
      'url': 'https://feeds.bbci.co.uk/turkce/rss.xml',
      'is_active': 1,
      'created_at': now,
    });
    await db.insert('news_sources', {
      'id': 'src-aa-guncel',
      'name': 'Anadolu Ajansı Güncel',
      'url': 'https://www.aa.com.tr/tr/rss/default?cat=guncel',
      'is_active': 1,
      'created_at': now,
    });
    await db.insert('news_sources', {
      'id': 'src-ntv-gundem',
      'name': 'NTV Gündem',
      'url': 'https://www.ntv.com.tr/gundem.rss',
      'is_active': 1,
      'created_at': now,
    });
  }

  // --- Ayar Metotları ---
  Future<String?> getSetting(String key) async {
    final db = await database;
    final res = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) {
      return res.first['value'] as String?;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final res = await db.query('app_settings');
    final Map<String, String> map = {};
    for (var row in res) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }

  // --- Editör Hafızası Metotları (AI'nin Öğrenmesi İçin) ---
  Future<void> recordUserEdit({
    required String originalTitle,
    required String aiTitle,
    required String userEditedTitle,
    required String originalContent,
    required String aiContent,
    required String userEditedContent,
  }) async {
    final db = await database;
    // Eğer kullanıcı gerçekten bir değişiklik yaptıysa hafızaya kaydet
    if (aiTitle != userEditedTitle || aiContent != userEditedContent) {
      await db.insert('editorial_learning', {
        'original_title': originalTitle,
        'ai_title': aiTitle,
        'user_edited_title': userEditedTitle,
        'original_content': originalContent,
        'ai_content': aiContent,
        'user_edited_content': userEditedContent,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> getRecentLearnedEdits({int limit = 3}) async {
    final db = await database;
    return await db.query(
      'editorial_learning',
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  Future<int> getLearnedEditsCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM editorial_learning');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // --- Haber Kaynakları Metotları ---
  Future<List<Map<String, dynamic>>> getActiveSources() async {
    final db = await database;
    return await db.query('news_sources', where: 'is_active = ?', whereArgs: [1]);
  }

  Future<List<Map<String, dynamic>>> getAllSources() async {
    final db = await database;
    return await db.query('news_sources', orderBy: 'created_at DESC');
  }

  Future<void> insertSource(String id, String name, String url, bool isActive) async {
    final db = await database;
    await db.insert(
      'news_sources',
      {
        'id': id,
        'name': name,
        'url': url,
        'is_active': isActive ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> toggleSourceActive(String id, bool isActive) async {
    final db = await database;
    await db.update(
      'news_sources',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSource(String id) async {
    final db = await database;
    await db.delete('news_sources', where: 'id = ?', whereArgs: [id]);
  }

  // --- Taslak Haber Metotları ---
  Future<List<Map<String, dynamic>>> getPendingDrafts() async {
    final db = await database;
    return await db.query(
      'news_drafts',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'created_at DESC',
    );
  }

  Future<bool> isUrlAlreadyScraped(String url) async {
    final db = await database;
    final res = await db.query('news_drafts', where: 'source_url = ?', whereArgs: [url]);
    return res.isNotEmpty;
  }

  Future<void> insertDraft(Map<String, dynamic> draft) async {
    final db = await database;
    await db.insert('news_drafts', draft, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> updateDraftStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'news_drafts',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDraftContent({
    required String id,
    required String title,
    required String content,
    required String status,
  }) async {
    final db = await database;
    await db.update(
      'news_drafts',
      {
        'ai_title': title,
        'ai_content': content,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllPendingDrafts() async {
    final db = await database;
    await db.delete('news_drafts', where: 'status = ?', whereArgs: ['PENDING']);
  }

  Future<void> deleteDraftsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete('news_drafts', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  // --- Otonom Web Kazıyıcı: Öğrenilen Site Kuralları ---
  Future<void> saveLearnedRule({
    required String domain,
    String? cardSelector,
    String? urlPattern,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'site_learned_rules',
      {
        'domain': domain.toLowerCase(),
        'card_selector': cardSelector,
        'url_pattern': urlPattern,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLearnedRule(String domain) async {
    final db = await database;
    final res = await db.query(
      'site_learned_rules',
      where: 'domain = ?',
      whereArgs: [domain.toLowerCase()],
    );
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }
}

