import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

class LyricsOverlay extends StatefulWidget {
  const LyricsOverlay({super.key});

  @override
  State<LyricsOverlay> createState() => _LyricsOverlayState();
}

class _LyricsOverlayState extends State<LyricsOverlay> {
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -1;
  bool _isUserScrolling = false;
  Timer? _resumeScrollTimer;

  @override
  void dispose() {
    _resumeScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index, int total) {
    if (_isUserScrolling || index == _lastIndex || !_scrollController.hasClients || index < 0) return;
    _lastIndex = index;

    // Approximate line height 72px, offset to center
    const itemHeight = 72.0;
    final targetOffset = (index * itemHeight) - 200.0;
    final clamped = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final song = player.currentSong;

    if (!player.isShowingLyrics || song == null) {
      return const SizedBox.shrink();
    }

    _scrollToActiveLine(player.currentLyricIndex, player.lyrics.length);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 1. Blurred background using album art
            if (song.album.picUrl.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: song.album.picUrl,
                  fit: BoxFit.cover,
                ),
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
            ),

            // 2. Action buttons in top-right (Translation toggle + Close)
            Positioned(
              top: 54,
              right: 28,
              child: Row(
                children: [
                  // Translation toggle
                  InkWell(
                    onTap: () => player.toggleTranslation(),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: player.showTranslation
                            ? theme.primaryColor.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: player.showTranslation
                            ? Border.all(color: theme.primaryColor, width: 1)
                            : null,
                      ),
                      child: Text(
                        '译',
                        style: TextStyle(
                          color: player.showTranslation ? theme.primaryColor : Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Close button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    ),
                    onPressed: () => player.toggleLyrics(false),
                    tooltip: '关闭歌词 (Esc)',
                  ),
                ],
              ),
            ),

            // 3. Main Content: Left album art info, Right synced lyrics
            Positioned.fill(
              top: 48,
              bottom: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                child: Row(
                  children: [
                    // Left Column: Artwork + Song Meta
                    SizedBox(
                      width: 320,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Large Cover Art
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: song.album.picUrl,
                              width: 280,
                              height: 280,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                width: 280,
                                height: 280,
                                color: Colors.white10,
                                child: const Icon(Icons.music_note_rounded, size: 80, color: Colors.white24),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Song Name
                          Text(
                            song.name,
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
                          // Artist Name (Clickable)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                if (song.artists.isNotEmpty) {
                                  final a = song.artists[0];
                                  player.toggleLyrics(false);
                                  player.navigateTo('artistDetail', id: a.id, meta: a);
                                }
                              },
                              child: Text(
                                song.artistText,
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Album Name (Clickable)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                player.toggleLyrics(false);
                                player.navigateTo('albumDetail', id: song.album.id, meta: song.album);
                              },
                              child: Text(
                                song.album.name,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 40),

                    // Right Column: Synced Lyrics List
                    Expanded(
                      child: player.lyrics.isEmpty
                          ? const Center(
                              child: Text(
                                '暂无歌词',
                                style: TextStyle(color: Colors.white38, fontSize: 16),
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification is UserScrollNotification) {
                                  if (notification.direction != ScrollDirection.idle) {
                                    _isUserScrolling = true;
                                    _resumeScrollTimer?.cancel();
                                    _resumeScrollTimer = Timer(const Duration(seconds: 4), () {
                                      if (mounted) {
                                        setState(() {
                                          _isUserScrolling = false;
                                        });
                                      }
                                    });
                                  }
                                }
                                return false;
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 200),
                                itemCount: player.lyrics.length,
                                itemBuilder: (ctx, index) {
                                  final line = player.lyrics[index];
                                  final isCurrent = index == player.currentLyricIndex;

                                  return InkWell(
                                    onTap: () {
                                      _isUserScrolling = false;
                                      _resumeScrollTimer?.cancel();
                                      player.seek(Duration(milliseconds: (line.time * 1000).toInt()));
                                      _lastIndex = -1;
                                      _scrollToActiveLine(index, player.lyrics.length);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            line.text,
                                            style: TextStyle(
                                              color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.35),
                                              fontSize: isCurrent ? 24 : 17,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                              shadows: isCurrent
                                                  ? [
                                                      BoxShadow(
                                                        color: theme.primaryColor.withValues(alpha: 0.6),
                                                        blurRadius: 18,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                          ),
                                          if (player.showTranslation && line.translation != null && line.translation!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              line.translation!,
                                              style: TextStyle(
                                                color: isCurrent
                                                    ? Colors.white.withValues(alpha: 0.85)
                                                    : Colors.white.withValues(alpha: 0.25),
                                                fontSize: isCurrent ? 15 : 13,
                                                fontWeight: isCurrent ? FontWeight.w500 : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
