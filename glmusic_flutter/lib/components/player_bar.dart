import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final song = player.currentSong;

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Playback controls
          _buildPlaybackControls(player, theme),

          const SizedBox(width: 16),

          // Center: Album Art + Song Info + Progress Scrubber
          Expanded(
            child: _buildCenterSection(player, theme, song),
          ),

          const SizedBox(width: 16),

          // Right: Quality, Lyrics, Queue, Volume
          _buildExtrasSection(context, player, theme),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(PlayerProvider player, ThemeProvider theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shuffle
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            size: 17,
            color: player.isShuffled ? theme.primaryColor : Colors.white60,
          ),
          onPressed: player.toggleShuffle,
          tooltip: '随机播放',
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),

        // Previous
        IconButton(
          icon: const Icon(
            Icons.skip_previous_rounded,
            size: 24,
            color: Colors.white,
          ),
          onPressed: player.previous,
          tooltip: '上一首',
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),

        // Play / Pause
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: IconButton(
            icon: player.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                    ),
                  )
                : Icon(
                    player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
            onPressed: player.togglePlayPause,
            tooltip: player.isPlaying ? '暂停' : '播放',
            splashRadius: 22,
            padding: EdgeInsets.zero,
          ),
        ),

        // Next
        IconButton(
          icon: const Icon(
            Icons.skip_next_rounded,
            size: 24,
            color: Colors.white,
          ),
          onPressed: player.next,
          tooltip: '下一首',
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),

        // Repeat mode
        IconButton(
          icon: Icon(
            player.repeatMode == PlayRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            size: 18,
            color: player.repeatMode != PlayRepeatMode.off ? theme.primaryColor : Colors.white60,
          ),
          onPressed: player.cycleRepeat,
          tooltip: player.repeatMode.label,
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildCenterSection(PlayerProvider player, ThemeProvider theme, Song? song) {
    if (song == null) {
      return const Center(
        child: Text(
          '未在播放',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    final curMs = player.currentPosition.inMilliseconds;
    final totalMs = player.totalDuration.inMilliseconds > 0
        ? player.totalDuration.inMilliseconds
        : (song.duration > 0 ? song.duration : 1);
    final sliderValue = (curMs / totalMs).clamp(0.0, 1.0);

    return Row(
      children: [
        // Artwork (Click to toggle lyrics)
        GestureDetector(
          onTap: () => player.toggleLyrics(),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: song.album.picUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: song.album.picUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _albumArtPlaceholder(),
                    )
                  : _albumArtPlaceholder(),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Title + Artist + Scrubber
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: Song Name, Quality Badge, Artist
              Row(
                children: [
                  Flexible(
                    child: Text(
                      song.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quality Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.4),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      player.soundQuality.label,
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      song.artistText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Scrubber Slider
              Row(
                children: [
                  Text(
                    _formatDuration(player.currentPosition),
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontFeatures: []),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: theme.primaryColor,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: sliderValue,
                        onChanged: (val) {
                          final targetMs = (val * totalMs).round();
                          player.seek(Duration(milliseconds: targetMs));
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(player.totalDuration),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Like button
        IconButton(
          icon: Icon(
            player.likedSongIds.contains(song.id)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: 20,
            color: player.likedSongIds.contains(song.id) ? theme.primaryColor : Colors.white54,
          ),
          onPressed: () => player.toggleLike(song),
          tooltip: '喜欢',
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildExtrasSection(BuildContext context, PlayerProvider player, ThemeProvider theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quality selector menu
        PopupMenuButton<SoundQuality>(
          tooltip: '音质',
          offset: const Offset(0, -180),
          color: const Color(0xFF1E2028),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          onSelected: (quality) => player.setSoundQuality(quality),
          itemBuilder: (ctx) => SoundQuality.values.map((q) {
            final isSelected = q == player.soundQuality;
            return PopupMenuItem(
              value: q,
              child: Row(
                children: [
                  Text(
                    q.label,
                    style: TextStyle(
                      color: isSelected ? theme.primaryColor : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check, size: 16, color: theme.primaryColor),
                ],
              ),
            );
          }).toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              player.soundQuality.label,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Lyrics overlay toggle
        IconButton(
          icon: Icon(
            Icons.lyrics_rounded,
            size: 20,
            color: player.isShowingLyrics ? theme.primaryColor : Colors.white60,
          ),
          onPressed: () => player.toggleLyrics(),
          tooltip: '歌词',
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),

        // Play queue toggle
        IconButton(
          icon: Icon(
            Icons.queue_music_rounded,
            size: 22,
            color: player.isShowingQueue ? theme.primaryColor : Colors.white60,
          ),
          onPressed: () => player.toggleQueue(),
          tooltip: '播放列表',
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),

        const SizedBox(width: 6),

        // Volume control
        Icon(
          player.volume == 0
              ? Icons.volume_off_rounded
              : player.volume < 0.5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
          size: 18,
          color: Colors.white60,
        ),
        SizedBox(
          width: 80,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
              activeTrackColor: Colors.white70,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: player.volume,
              onChanged: (vol) => player.setVolume(vol),
            ),
          ),
        ),
      ],
    );
  }

  Widget _albumArtPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      color: Colors.white10,
      child: const Icon(Icons.music_note_rounded, color: Colors.white30, size: 24),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s < 10 ? '0' : ''}$s';
  }
}
