import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/publisher_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PublisherService _publisherService = PublisherService();

  final _geminiKeyController = TextEditingController();
  final _aiPromptController = TextEditingController();
  final _telegramTokenController = TextEditingController();
  final _telegramChatIdController = TextEditingController();

  String _geminiModel = 'gemini-1.5-flash';
  int _learnedEditsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getAllSettings();
    final count = await DatabaseHelper.instance.getLearnedEditsCount();

    setState(() {
      _geminiKeyController.text = settings['gemini_api_key'] ?? '';
      _geminiModel = settings['gemini_model'] ?? 'gemini-1.5-flash';
      _aiPromptController.text = settings['ai_custom_instructions'] ?? '';
      _telegramTokenController.text = settings['telegram_bot_token'] ?? '';
      _telegramChatIdController.text = settings['telegram_chat_id'] ?? '';
      _learnedEditsCount = count;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final db = DatabaseHelper.instance;
    await db.setSetting('gemini_api_key', _geminiKeyController.text.trim());
    await db.setSetting('gemini_model', _geminiModel);
    await db.setSetting('ai_custom_instructions', _aiPromptController.text.trim());
    await db.setSetting('telegram_bot_token', _telegramTokenController.text.trim());
    await db.setSetting('telegram_chat_id', _telegramChatIdController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ayarlar başarıyla kaydedildi!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _testTelegram() async {
    final token = _telegramTokenController.text.trim();
    final chatId = _telegramChatIdController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce Bot Token girin.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Telegram test ediliyor...')),
    );

    final res = await _publisherService.testTelegram(token, chatId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']),
          backgroundColor: res['success'] ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar & Entegrasyon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Kaydet',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. YAPAY ZEKA & ÖĞRENEN HAFIZA KARTI
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology_rounded, color: Colors.purple, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Google Gemini & Editör Hafızası',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Öğrenme İstatistiği Rozeti
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school_rounded, color: Colors.purple),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Yapay zeka şu ana kadar sizden $_learnedEditsCount düzeltme öğrendi.',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _geminiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Google Gemini API Anahtarı',
                      hintText: 'AIzaSy...',
                      helperText: 'aistudio.google.com adresinden tamamen ücretsiz alınabilir',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _aiPromptController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'AI Üslup ve Düzenleme Talimatı (Prompt)',
                      hintText: 'Haberleri nasıl özetlemesini ve başlık atmasını istiyorsanız buraya yazın...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. TELEGRAM KARTI
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.telegram, color: Color(0xFF229ED9), size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Telegram Kanal Yayını',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _telegramTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Telegram Bot Token',
                      hintText: '7123456789:AAH...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.smart_toy_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _telegramChatIdController,
                    decoration: const InputDecoration(
                      labelText: 'Kanal Kullanıcı Adı veya ID',
                      hintText: '@benim_haber_kanali veya -100...',
                      helperText: '⚠️ Bot adını değil, haberlerin gideceği KANAL adını (Örn: @haberkanalim) yazın. Botu da kanalda Yönetici yapın.',
                      helperMaxLines: 3,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _testTelegram,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Telegram Bağlantısını Test Et & Mesaj At'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // KAYDET BUTONU
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Tüm Ayarları Kaydet'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
