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
                        if (player.queue.isNotEmpty)
                          TextButton(
                            onPressed: () => player.clearQueue(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white54,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('清空', style: TextStyle(fontSize: 11)),
                          ),
                        const SizedBox(width: 4),
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

                  // Queue List with Reorderable Drag & Drop
                  Expanded(
                    child: player.queue.isEmpty
                        ? const Center(
                            child: Text(
                              '播放列表为空',
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            buildDefaultDragHandles: false,
                            itemCount: player.queue.length,
                            // ignore: deprecated_member_use
                            onReorder: (oldIndex, newIndex) {
                              player.reorderQueue(oldIndex, newIndex);
                            },
                            itemBuilder: (ctx, index) {
                              final song = player.queue[index];
                              final isCurrent = player.currentSong?.id == song.id;

                              return Container(
                                key: ValueKey('queue_${song.id}_$index'),
                                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? theme.primaryColor.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => player.playSong(song, index: index),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      children: [
                                        // Index or Playing indicator
                                        SizedBox(
                                          width: 22,
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
                                        const SizedBox(width: 4),
                                        // Remove button
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 14, color: Colors.white24),
                                          onPressed: () => player.removeFromQueue(index),
                                          tooltip: '从队列中移除',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                        ),
                                        // Drag reorder handle
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: const MouseRegion(
                                            cursor: SystemMouseCursors.grab,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 4),
                                              child: Icon(
                                                Icons.drag_indicator_rounded,
                                                size: 16,
                                                color: Colors.white24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
