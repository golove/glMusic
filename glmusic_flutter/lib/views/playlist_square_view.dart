import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';

class PlaylistSquareView extends StatefulWidget {
  const PlaylistSquareView({super.key});

  @override
  State<PlaylistSquareView> createState() => _PlaylistSquareViewState();
}

class _PlaylistSquareViewState extends State<PlaylistSquareView> {
  final RustCoreService _core = RustCoreService();

  static const List<String> _categories = [
    '全部',
    '华语',
    '流行',
    '摇滚',
    '民谣',
    '电子',
    '轻音乐',
    'ACG',
    '欧美',
    '说唱',
  ];

  String _currentCategory = '全部';
  List<Playlist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() => _isLoading = true);
    try {
      final list = await _core.getTopPlaylists(cat: _currentCategory, limit: 35);
      if (mounted) {
        setState(() {
          _playlists = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategorySelected(String cat) {
    if (_currentCategory == cat) return;
    setState(() {
      _currentCategory = cat;
    });
    _loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.read<PlayerProvider>();

    return Column(
      children: [
        // Category Pills Bar
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.centerLeft,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, index) {
              final cat = _categories[index];
              final isSelected = cat == _currentCategory;

              return Center(
                child: InkWell(
                  onTap: () => _onCategorySelected(cat),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primaryColor.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: theme.primaryColor, width: 1)
                          : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? theme.primaryColor : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Grid Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(4, 7);

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 90),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 18,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: _playlists.length,
                      itemBuilder: (ctx, index) {
                        final pl = _playlists[index];
                        return InkWell(
                          onTap: () {
                            player.navigateTo('playlistDetail', id: pl.id, meta: pl);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: pl.coverImgUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => Container(color: Colors.white12),
                                      ),
                                      if (pl.playCount != null)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 12),
                                                const SizedBox(width: 2),
                                                Text(
                                                  _formatPlayCount(pl.playCount!),
                                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                pl.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatPlayCount(int count) {
    if (count > 100000000) {
      return '${(count / 100000000).toStringAsFixed(1)}亿';
    }
    if (count > 10000) {
      return '${(count / 10000).toStringAsFixed(0)}万';
    }
    return count.toString();
  }
}
