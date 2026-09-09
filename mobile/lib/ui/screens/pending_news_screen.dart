import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/pending_news/pending_news_bloc.dart';
import '../../bloc/pending_news/pending_news_event.dart';
import '../../bloc/pending_news/pending_news_state.dart';
import '../../repositories/news_repository.dart';
import '../widgets/draft_card.dart';
import 'review_detail_screen.dart';
import 'settings_screen.dart';
import 'sources_screen.dart';

class PendingNewsScreen extends StatefulWidget {
  final NewsRepository newsRepository;

  const PendingNewsScreen({Key? key, required this.newsRepository}) : super(key: key);

  @override
  State<PendingNewsScreen> createState() => _PendingNewsScreenState();
}

class _PendingNewsScreenState extends State<PendingNewsScreen> {
  bool _isScanning = false;
  String _scanStatusText = '';

  // Çoklu Seçim ve Silme Durumu
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String? initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll(List<String> allIds) {
    setState(() {
      if (_selectedIds.length == allIds.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seçilenleri Sil?'),
        content: Text('${_selectedIds.length} adet haber taslağını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<PendingNewsBloc>().add(DeleteSelectedDrafts(_selectedIds.toList()));
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seçilen haberler silindi.'), backgroundColor: Colors.grey),
      );
    }
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Tümünü Sil?'),
          ],
        ),
        content: const Text(
          'Bekleyen BÜTÜN haber taslaklarını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tümünü Temizle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<PendingNewsBloc>().add(DeleteAllPendingDrafts());
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm taslaklar temizlendi.'), backgroundColor: Colors.grey),
      );
    }
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _scanStatusText = 'Siteler taranıyor...';
    });

    try {
      await for (final status in widget.newsRepository.scanAndProcessNews()) {
        if (mounted) {
          setState(() {
            _scanStatusText = status;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarama Hatası: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        context.read<PendingNewsBloc>().add(const FetchPendingNews(isRefresh: true));
      }
    }
  }

  void _showPasteLinkDialog() {
    final linkController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Hızlı Link Yapıştır'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İstediğiniz herhangi bir haber linkini buraya yapıştırın. Sayfadaki metin ve görsel çekilip Gemini ile özetlenir.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkController,
              decoration: const InputDecoration(
                labelText: 'Haber URL Adresi',
                hintText: 'https://site.com/haber...',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final url = linkController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sayfa taranıyor ve Gemini ile özetleniyor...')),
                );
                try {
                  await widget.newsRepository.scrapeSingleUrl(url);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Haber hazırlandı ve listeye eklendi!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    context.read<PendingNewsBloc>().add(const FetchPendingNews(isRefresh: true));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Çek & Özetle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar(theme) : _buildNormalAppBar(theme),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _isScanning ? null : _startScanning,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isScanning ? 'İşleniyor...' : 'Tara & AI ile Getir'),
            ),
      body: Column(
        children: [
          if (_isScanning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _scanStatusText,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: BlocConsumer<PendingNewsBloc, PendingNewsState>(
              listener: (context, state) {
                if (state.status == PendingNewsStatus.error && state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == PendingNewsStatus.loading && !state.isRefreshing) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.drafts.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<PendingNewsBloc>().add(const FetchPendingNews(isRefresh: true));
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inbox_rounded, size: 72, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Bekleyen Haber Yok',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Haber sitelerini tarayarak veya üstteki link butonuna bir adres yapıştırarak haber çekebilirsiniz.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _isScanning ? null : _startScanning,
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: const Text('Siteleri Tara & AI ile Getir'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<PendingNewsBloc>().add(const FetchPendingNews(isRefresh: true));
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 90),
                    itemCount: state.drafts.length,
                    itemBuilder: (context, index) {
                      final draft = state.drafts[index];
                      final isSelected = _selectedIds.contains(draft.id);

                      return DraftCard(
                        draft: draft,
                        isSelectionMode: _isSelectionMode,
                        isSelected: isSelected,
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _enterSelectionMode(draft.id);
                          }
                        },
                        onSelectChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedIds.add(draft.id);
                            } else {
                              _selectedIds.remove(draft.id);
                              if (_selectedIds.isEmpty) {
                                _exitSelectionMode();
                              }
                            }
                          });
                        },
                        onTap: () async {
                          if (_isSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(draft.id);
                                if (_selectedIds.isEmpty) _exitSelectionMode();
                              } else {
                                _selectedIds.add(draft.id);
                              }
                            });
                          } else {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReviewDetailScreen(draft: draft),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildNormalAppBar(ThemeData theme) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Haber Asistanı'),
          BlocBuilder<PendingNewsBloc, PendingNewsState>(
            builder: (context, state) {
              if (state.status == PendingNewsStatus.loaded) {
                return Text(
                  '${state.drafts.length} taslak onay bekliyor',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: theme.colorScheme.primary,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_link_rounded),
          tooltip: 'Hızlı Link Yapıştır & Özetle',
          onPressed: _showPasteLinkDialog,
        ),
        IconButton(
          icon: const Icon(Icons.language_rounded),
          tooltip: 'Haber Siteleri',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SourcesScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Ayarlar',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        // Çoklu Seçim veya Tümünü Silme Menüsü
        BlocBuilder<PendingNewsBloc, PendingNewsState>(
          builder: (context, state) {
            if (state.drafts.isEmpty) return const SizedBox.shrink();
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == 'select_mode') {
                  _enterSelectionMode(null);
                } else if (val == 'delete_all') {
                  _deleteAll();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'select_mode',
                  child: Row(
                    children: [
                      Icon(Icons.checklist_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Seçerek Sil'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Tümünü Temizle', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(ThemeData theme) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Seçimi Kapat',
        onPressed: _exitSelectionMode,
      ),
      title: Text('${_selectedIds.length} Seçildi'),
      actions: [
        BlocBuilder<PendingNewsBloc, PendingNewsState>(
          builder: (context, state) {
            final allIds = state.drafts.map((d) => d.id).toList();
            final isAllSelected = _selectedIds.length == allIds.length && allIds.isNotEmpty;
            return IconButton(
              icon: Icon(isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
              tooltip: isAllSelected ? 'Seçimi Kaldır' : 'Tümünü Seç',
              onPressed: () => _toggleSelectAll(allIds),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_rounded, color: Colors.red),
          tooltip: 'Seçilenleri Sil',
          onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
        ),
      ],
    );
  }
}
