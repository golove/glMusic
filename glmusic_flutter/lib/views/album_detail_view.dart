import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';
import '../components/song_row.dart';

class AlbumDetailView extends StatefulWidget {
  final int albumId;
  final Album? initialAlbum;

  const AlbumDetailView({
    super.key,
    required this.albumId,
    this.initialAlbum,
  });

  @override
  State<AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<AlbumDetailView> {
  final RustCoreService _core = RustCoreService();
  Album? _album;
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _album = widget.initialAlbum;
    _loadAlbum();
  }

  Future<void> _loadAlbum() async {
    setState(() => _isLoading = true);
    try {
      final (album, songs) = await _core.getAlbum(widget.albumId);
      if (mounted) {
        setState(() {
          _album = album;
          _songs = songs;
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

    if (_isLoading && _songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final album = _album ?? widget.initialAlbum;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 90),
      children: [
        // Album Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: album?.picUrl.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: album!.picUrl,
                      width: 170,
                      height: 170,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 170,
                      height: 170,
                      color: Colors.white10,
                      child: const Icon(Icons.album_rounded, size: 60, color: Colors.white30),
                    ),
            ),

            const SizedBox(width: 24),

            // Metadata & Actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album?.name ?? '专辑详情',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Artist Name
                  if (album?.artist != null) ...[
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          final a = album?.artist;
                          if (a != null) {
                            player.navigateTo(
                              'artistDetail',
                              id: a.id,
                              meta: a,
                            );
                          }
                        },
                        child: Text(
                          album?.artist?.name ?? '',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Details
                  Row(
                    children: [
                      if (album?.publishTime != null) ...[
                        Text(
                          _formatPublishYear(album!.publishTime!),
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        '共 ${_songs.length} 首歌',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Action Buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('播放全部'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        onPressed: _songs.isEmpty
                            ? null
                            : () => player.playSong(_songs[0], newQueue: _songs, index: 0),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: const Text('打乱播放'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _songs.isEmpty
                            ? null
                            : () {
                                final shuffled = List<Song>.from(_songs)..shuffle();
                                player.playSong(shuffled[0], newQueue: shuffled, index: 0);
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: const [
              SizedBox(width: 34, child: Text('#', style: TextStyle(color: Colors.white38, fontSize: 12))),
              Expanded(flex: 5, child: Text('歌曲', style: TextStyle(color: Colors.white38, fontSize: 12))),
              Expanded(flex: 3, child: Text('歌手', style: TextStyle(color: Colors.white38, fontSize: 12))),
              SizedBox(width: 90, child: Text('时长', style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.right)),
            ],
          ),
        ),

        const Divider(color: Colors.white10, height: 1),

        // Songs Table
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _songs.length,
          itemBuilder: (ctx, index) {
            final song = _songs[index];
            return SongRow(
              index: index,
              song: song,
              queue: _songs,
              showAlbum: false,
              showCover: false,
            );
          },
        ),
      ],
    );
  }

  String _formatPublishYear(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${date.year}年${date.month}月${date.day}日 发行';
  }
}
