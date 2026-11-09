import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';

class DailyRecommendView extends StatefulWidget {
  const DailyRecommendView({super.key});

  @override
  State<DailyRecommendView> createState() => _DailyRecommendViewState();
}

class _DailyRecommendViewState extends State<DailyRecommendView> {
  final RustCoreService _core = RustCoreService();
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailySongs();
  }

  Future<void> _loadDailySongs() async {
    setState(() => _isLoading = true);
    try {
      final songs = await _core.getDailyRecommendSongs();
      if (mounted) {
        setState(() {
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
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final now = DateTime.now();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 90),
      children: [
        // Daily Header Card
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Calendar icon / date box
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _monthName(now.month),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${now.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 20),

            // Title & Actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '每日推荐',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '根据你的音乐口味生成 · 每天 06:00 更新',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Play All Button
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
                      // Shuffle Button
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

        // Songs Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: const [
              SizedBox(width: 36, child: Text('#', style: TextStyle(color: Colors.white38, fontSize: 12))),
              Expanded(flex: 5, child: Text('歌曲', style: TextStyle(color: Colors.white38, fontSize: 12))),
              Expanded(flex: 3, child: Text('歌手', style: TextStyle(color: Colors.white38, fontSize: 12))),
              Expanded(flex: 4, child: Text('专辑', style: TextStyle(color: Colors.white38, fontSize: 12))),
              SizedBox(width: 80, child: Text('时长', style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.right)),
            ],
          ),
        ),

        const Divider(color: Colors.white10, height: 1),

        // Song Rows
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _songs.length,
          itemBuilder: (ctx, index) {
            final song = _songs[index];
            final isCurrent = player.currentSong?.id == song.id;

            return InkWell(
              onTap: () => player.playSong(song, newQueue: _songs, index: index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.primaryColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Index
                    SizedBox(
                      width: 36,
                      child: isCurrent && player.isPlaying
                          ? Icon(Icons.volume_up_rounded, size: 16, color: theme.primaryColor)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent ? theme.primaryColor : Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                    ),

                    // Title + Cover
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: song.album.picUrl,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(color: Colors.white10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              song.name,
                              style: TextStyle(
                                color: isCurrent ? theme.primaryColor : Colors.white,
                                fontSize: 13,
                                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Artist
                    Expanded(
                      flex: 3,
                      child: Text(
                        song.artistText,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Album
                    Expanded(
                      flex: 4,
                      child: Text(
                        song.album.name,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Duration + Like
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(
                              player.likedSongIds.contains(song.id)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 16,
                              color: player.likedSongIds.contains(song.id)
                                  ? theme.primaryColor
                                  : Colors.white38,
                            ),
                            onPressed: () => player.toggleLike(song),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            song.durationText,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
    return names[(month - 1).clamp(0, 11)];
  }
}
