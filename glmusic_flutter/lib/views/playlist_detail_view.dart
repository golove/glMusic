import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';
import '../components/song_row.dart';

class PlaylistDetailView extends StatefulWidget {
  final int playlistId;
  final Playlist? initialPlaylist;

  const PlaylistDetailView({
    super.key,
    required this.playlistId,
    this.initialPlaylist,
  });

  @override
  State<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<PlaylistDetailView> {
  final RustCoreService _core = RustCoreService();
  Playlist? _playlist;
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _playlist = widget.initialPlaylist;
    _loadPlaylistDetail();
  }

  Future<void> _loadPlaylistDetail() async {
    setState(() => _isLoading = true);
    try {
      final (pl, songs) = await _core.getPlaylistDetail(widget.playlistId);
      if (mounted) {
        setState(() {
          _playlist = pl;
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

    final pl = _playlist ?? widget.initialPlaylist;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 90),
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Art
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: pl?.coverImgUrl.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: pl!.coverImgUrl,
                      width: 170,
                      height: 170,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 170,
                      height: 170,
                      color: Colors.white10,
                      child: const Icon(Icons.music_note_rounded, size: 60, color: Colors.white30),
                    ),
            ),

            const SizedBox(width: 24),

            // Metadata & Actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pl?.name ?? '歌单详情',
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

                  // Creator info
                  if (pl?.creator != null) ...[
                    Row(
                      children: [
                        if (pl!.creator!['avatarUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: pl.creator!['avatarUrl'] as String,
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          pl.creator!['nickname'] as String? ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        if (pl.trackCount != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            '共 ${pl.trackCount} 首',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Description
                  if (pl?.description != null && pl!.description!.isNotEmpty)
                    Text(
                      pl.description!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 16),

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
              SizedBox(width: 48),
              Expanded(flex: 5, child: Text('歌曲', style: TextStyle(color: Colors.white38, fontSize: 12))),
              Expanded(flex: 3, child: Text('歌手', style: TextStyle(color: Colors.white38, fontSize: 12))),
              Expanded(flex: 4, child: Text('专辑', style: TextStyle(color: Colors.white38, fontSize: 12))),
              SizedBox(width: 90, child: Text('时长', style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.right)),
            ],
          ),
        ),

        const Divider(color: Colors.white10, height: 1),

        // Songs List
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
              showAlbum: true,
              showCover: true,
            );
          },
        ),
      ],
    );
  }
}
