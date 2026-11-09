import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

class QueueDrawer extends StatelessWidget {
  const QueueDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();

    if (!player.isShowingQueue) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 48,
      bottom: 80,
      right: 20,
      width: 340,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2028).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Row(
                      children: [
                        const Text(
                          '待播清单',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${player.queue.length} 首',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                          onPressed: () => player.toggleQueue(false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ),

                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

                  // Queue List
                  Expanded(
                    child: player.queue.isEmpty
                        ? const Center(
                            child: Text(
                              '播放列表为空',
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: player.queue.length,
                            separatorBuilder: (_, _) => Divider(
                              color: Colors.white.withValues(alpha: 0.03),
                              height: 1,
                            ),
                            itemBuilder: (ctx, index) {
                              final song = player.queue[index];
                              final isCurrent = player.currentSong?.id == song.id;

                              return InkWell(
                                onTap: () => player.playSong(song, index: index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  color: isCurrent
                                      ? theme.primaryColor.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  child: Row(
                                    children: [
                                      // Index or Playing indicator
                                      SizedBox(
                                        width: 24,
                                        child: isCurrent
                                            ? Icon(Icons.volume_up_rounded, size: 16, color: theme.primaryColor)
                                            : Text(
                                                '${index + 1}',
                                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Title + Artist
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              song.name,
                                              style: TextStyle(
                                                color: isCurrent ? theme.primaryColor : Colors.white,
                                                fontSize: 13,
                                                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              song.artistText,
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Duration
                                      Text(
                                        song.durationText,
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
