import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/news_draft.dart';
import '../../bloc/review_action/review_action_bloc.dart';
import '../../bloc/review_action/review_action_event.dart';
import '../../bloc/review_action/review_action_state.dart';
import '../../bloc/pending_news/pending_news_bloc.dart';
import '../../bloc/pending_news/pending_news_event.dart';

class ReviewDetailScreen extends StatefulWidget {
  final NewsDraft draft;

  const ReviewDetailScreen({Key? key, required this.draft}) : super(key: key);

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _imageUrlController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _titleController = TextEditingController(
      text: widget.draft.aiTitle?.isNotEmpty == true
          ? widget.draft.aiTitle
          : widget.draft.originalTitle ?? '',
    );

    _contentController = TextEditingController(
      text: widget.draft.aiContent?.isNotEmpty == true
          ? widget.draft.aiContent
          : widget.draft.originalContent ?? '',
    );

    _imageUrlController = TextEditingController(
      text: widget.draft.imageUrl ?? '',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _showRejectConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Taslağı Reddet?'),
          ],
        ),
        content: const Text(
          'Bu haberi reddetmek istediğinize emin misiniz? Kanala gönderilmeyecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _submitDecision('reject');
            },
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
  }

  void _submitDecision(String action) {
    context.read<ReviewActionBloc>().add(
          SubmitReviewDecision(
            draftId: widget.draft.id,
            action: action,
            originalTitle: widget.draft.originalTitle ?? '',
            originalContent: widget.draft.originalContent ?? '',
            aiTitle: widget.draft.aiTitle ?? '',
            aiContent: widget.draft.aiContent ?? '',
            finalTitle: _titleController.text.trim(),
            finalContent: _contentController.text.trim(),
            imageUrl: _imageUrlController.text.trim().isNotEmpty
                ? _imageUrlController.text.trim()
                : null,
            targetPlatforms: const ['telegram'],
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<ReviewActionBloc, ReviewActionState>(
      listener: (context, state) {
        if (state.status == ReviewActionStatus.success) {
          context.read<PendingNewsBloc>().add(RemoveDraftFromList(widget.draft.id));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.message ?? 'İşlem tamamlandı!')),
                ],
              ),
              backgroundColor: state.action == 'approve' ? Colors.green : Colors.grey[800],
              duration: const Duration(seconds: 3),
            ),
          );

          context.read<ReviewActionBloc>().add(ResetReviewActionState());
          Navigator.pop(context, true);
        } else if (state.status == ReviewActionStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.message ?? 'Bir hata oluştu.')),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('İncele & Yayınla'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.edit_note_rounded),
                text: 'AI Düzenleyici',
              ),
              Tab(
                icon: Icon(Icons.compare_rounded),
                text: 'Orijinal Metin',
              ),
            ],
          ),
        ),
        body: BlocBuilder<ReviewActionBloc, ReviewActionState>(
          builder: (context, state) {
            final isSubmitting = state.status == ReviewActionStatus.submitting;

            return Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAiEditorTab(theme, isDark, isSubmitting),
                    _buildOriginalScrapedTab(theme, isDark),
                  ],
                ),
                if (isSubmitting)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                state.action == 'approve'
                                    ? 'Telegram Kanalına Yayınlanıyor...'
                                    : 'Taslak Reddediliyor...',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAiEditorTab(ThemeData theme, bool isDark, bool isSubmitting) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Görsel önizlemesi
        if (_imageUrlController.text.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: _imageUrlController.text,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Görsel URL kutusu
        TextField(
          controller: _imageUrlController,
          decoration: InputDecoration(
            labelText: 'Kapak Görseli URL',
            prefixIcon: const Icon(Icons.image_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (val) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // AI Başlık Düzenleyici
        TextField(
          controller: _titleController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Haber Başlığı (Yapay Zeka Önerisi)',
            prefixIcon: const Icon(Icons.title_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            helperText: 'Düzenleme yaparsanız yapay zeka bu tarzınızı öğrenecektir.',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),

        // AI İçerik Düzenleyici
        TextField(
          controller: _contentController,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: 'Haber Özeti (2 Paragraf)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            helperText: 'Yayına göndermeden önce metni dilediğiniz gibi değiştirebilirsiniz.',
          ),
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 16),

        // Hedef Platform Bilgi Rozeti (Sadece Telegram)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF229ED9).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.telegram, color: Color(0xFF229ED9), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Yayın Hedefi: Telegram Kanalı',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF229ED9)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // CTA Aksiyon Butonları
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: isSubmitting ? null : _showRejectConfirmationDialog,
                icon: const Icon(Icons.close_rounded, color: Colors.red),
                label: const Text(
                  'Reddet',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : () => _submitDecision('approve'),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Onayla & Telegram\'a At'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF229ED9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _openSourceUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    try {
      final uri = Uri.parse(url.trim());
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı tarayıcıda açılamadı.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    }
  }

  Widget _buildOriginalScrapedTab(ThemeData theme, bool isDark) {
    final sourceUrl = widget.draft.sourceUrl;
    final hasValidUrl = sourceUrl != null &&
        (sourceUrl.startsWith('http://') || sourceUrl.startsWith('https://'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Kaynak URL Kartı ve Tarayıcıda Aç Butonu
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252525) : Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link_rounded, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Orijinal Kaynak Linki',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  if (hasValidUrl)
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      tooltip: 'Tarayıcıda Aç',
                      color: theme.colorScheme.primary,
                      onPressed: () => _openSourceUrl(sourceUrl),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: hasValidUrl ? () => _openSourceUrl(sourceUrl) : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    sourceUrl ?? 'Kaynak linki bulunamadı',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasValidUrl ? theme.colorScheme.primary : Colors.grey,
                      decoration: hasValidUrl ? TextDecoration.underline : TextDecoration.none,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              if (hasValidUrl) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                    ),
                    onPressed: () => _openSourceUrl(sourceUrl),
                    icon: const Icon(Icons.travel_explore_rounded, size: 20),
                    label: const Text(
                      'Haberi Web Sitesinde İncele 🌐',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Orijinal Başlık
        const Text(
          'Orijinal Taranan Başlık',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        SelectableText(
          widget.draft.originalTitle ?? 'Başlık yok',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(height: 32),

        // Orijinal Tam Metin İçeriği
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Orijinal Taranan Tam Metin',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              '${widget.draft.originalContent?.length ?? 0} Karakter',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
            ),
          ),
          child: SelectableText(
            widget.draft.originalContent ?? 'İçerik bulunamadı',
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
