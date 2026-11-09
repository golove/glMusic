import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';
import '../components/song_row.dart';
import '../components/hover_play_card.dart';

class ArtistDetailView extends StatefulWidget {
  final int artistId;
  final Artist? initialArtist;

  const ArtistDetailView({
    super.key,
    required this.artistId,
    this.initialArtist,
  });

  @override
  State<ArtistDetailView> createState() => _ArtistDetailViewState();
}

class _ArtistDetailViewState extends State<ArtistDetailView> {
  final RustCoreService _core = RustCoreService();

  Map<String, dynamic>? _artistData;
  List<Song> _hotSongs = [];
  List<Album> _albums = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Hot Songs, 1: Albums

  @override
  void initState() {
    super.initState();
    _loadArtist();
  }

  Future<void> _loadArtist() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _core.getArtistDetail(widget.artistId),
        _core.getArtistAlbums(widget.artistId, limit: 30),
      ]);

      final detail = results[0] as Map<String, dynamic>;
      final albums = results[1] as List<Album>;

      final rawSongs = (detail['hotSongs'] ?? []) as List<dynamic>;
      final hotSongs = rawSongs.map((s) => Song.fromRaw(s as Map<String, dynamic>)).toList();

      if (mounted) {
        setState(() {
          _artistData = detail['artist'] as Map<String, dynamic>? ?? {};
          _hotSongs = hotSongs;
          _albums = albums;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();

    if (_isLoading && _hotSongs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final artistName = _artistData?['name'] as String? ?? widget.initialArtist?.name ?? '艺人详情';
    final avatarUrl = (_artistData?['picUrl'] ?? _artistData?['img1v1Url'] ?? widget.initialArtist?.picUrl ?? '') as String;
    final briefDesc = _artistData?['briefDesc'] as String? ?? '';
    final musicSize = _artistData?['musicSize'] as num? ?? _hotSongs.length;
    final albumSize = _artistData?['albumSize'] as num? ?? _albums.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 90),
      children: [
        // Artist Hero Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          width: 140,
                          height: 140,
                          color: Colors.white10,
                          child: const Icon(Icons.person, size: 60, color: Colors.white30),
                        ),
                      )
                    : Container(
                        width: 140,
                        height: 140,
                        color: Colors.white10,
                        child: const Icon(Icons.person, size: 60, color: Colors.white30),
                      ),
              ),
            ),

            const SizedBox(width: 28),

            // Metadata & Actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artistName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '单曲 $musicSize 首 · 专辑 $albumSize 张',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  if (briefDesc.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      briefDesc,
                      style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('播放热门单曲'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        onPressed: _hotSongs.isEmpty
                            ? null
                            : () => player.playSong(_hotSongs[0], newQueue: _hotSongs, index: 0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Tabs: 热门歌曲 / 所有专辑
        Row(
          children: [
            _buildTab('热门歌曲 (${_hotSongs.length})', 0, theme),
            const SizedBox(width: 12),
            _buildTab('所有专辑 (${_albums.length})', 1, theme),
          ],
        ),

        const SizedBox(height: 16),

        // Tab Content
        if (_selectedTab == 0) ...[
          // Table Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: const [
                SizedBox(width: 34, child: Text('#', style: TextStyle(color: Colors.white38, fontSize: 12))),
                SizedBox(width: 48),
                Expanded(flex: 5, child: Text('歌曲', style: TextStyle(color: Colors.white38, fontSize: 12))),
                Expanded(flex: 3, child: Text('歌手', style: TextStyle(color: Colors.white38, fontSize: 12))),
                Expanded(flex: 4, child: Text('专辑', style: TextStyle(color: Colors.white38, fontSize: 12))),
                SizedBox(width: 90, child: Text('时长', style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _hotSongs.length,
            itemBuilder: (ctx, index) {
              final song = _hotSongs[index];
              return SongRow(
                index: index,
                song: song,
                queue: _hotSongs,
                showAlbum: true,
                showCover: true,
              );
            },
          ),
        ] else ...[
          // Albums Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(4, 7);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.78,
                ),
                itemCount: _albums.length,
                itemBuilder: (ctx, index) {
                  final album = _albums[index];
                  return HoverPlayCard(
                    title: album.name,
                    subtitle: album.publishTime != null
                        ? '${DateTime.fromMillisecondsSinceEpoch(album.publishTime!).year}'
                        : null,
                    imageUrl: album.picUrl,
                    onTap: () {
                      player.navigateTo('albumDetail', id: album.id, meta: album);
                    },
                    onPlay: () async {
                      try {
                        final (_, songs) = await _core.getAlbum(album.id);
                        if (songs.isNotEmpty) {
                          player.playSong(songs[0], newQueue: songs, index: 0);
                        }
                      } catch (_) {}
                    },
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTab(String label, int index, ThemeProvider theme) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: theme.primaryColor) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.primaryColor : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
