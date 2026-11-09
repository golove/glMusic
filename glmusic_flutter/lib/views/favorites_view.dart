import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../components/song_row.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final songs = player.favorites;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 90),
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '喜欢音乐',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '共 ${songs.length} 首',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            if (songs.isNotEmpty) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('播放全部'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                onPressed: () => player.playSong(songs[0], newQueue: songs, index: 0),
              ),
            ],
          ],
        ),

        const SizedBox(height: 24),

        if (songs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: Text('暂无喜欢音乐，点击歌曲右侧的爱心即可添加', style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
          )
        else ...[
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
            itemCount: songs.length,
            itemBuilder: (ctx, index) {
              final song = songs[index];
              return SongRow(
                index: index,
                song: song,
                queue: songs,
                showAlbum: true,
                showCover: true,
              );
            },
          ),
        ],
      ],
    );
  }
}
