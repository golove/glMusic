import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../components/song_row.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final songs = player.history;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 90),
      children: [
        // Header
        Row(
          children: [
            const Text(
              '播放历史',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '共 ${songs.length} 首',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const Spacer(),
            if (songs.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('清空历史'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => player.clearHistory(),
              ),
          ],
        ),

        const SizedBox(height: 20),

        if (songs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: Text(
                '暂无播放历史',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
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
