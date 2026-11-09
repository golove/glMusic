import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

class SongRow extends StatefulWidget {
  final int index;
  final Song song;
  final List<Song> queue;
  final bool showAlbum;
  final bool showCover;

  const SongRow({
    super.key,
    required this.index,
    required this.song,
    required this.queue,
    this.showAlbum = true,
    this.showCover = true,
  });

  @override
  State<SongRow> createState() => _SongRowState();
}

class _SongRowState extends State<SongRow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final isCurrent = player.currentSong?.id == widget.song.id;
    final isLiked = player.likedSongIds.contains(widget.song.id);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: () => player.playSong(widget.song, newQueue: widget.queue, index: widget.index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isCurrent
                ? theme.primaryColor.withValues(alpha: 0.12)
                : (_isHovering ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Index or Playing / Play Icon
              SizedBox(
                width: 34,
                child: _buildLeading(player, theme, isCurrent),
              ),

              const SizedBox(width: 4),

              // Cover Art (optional)
              if (widget.showCover) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: widget.song.album.picUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(color: Colors.white10),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Song Title
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.song.name,
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

              // Artist Name (Clickable)
              Expanded(
                flex: 3,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      if (widget.song.artists.isNotEmpty) {
                        final artist = widget.song.artists[0];
                        player.navigateTo('artistDetail', id: artist.id, meta: artist);
                      }
                    },
                    child: Text(
                      widget.song.artistText,
                      style: TextStyle(
                        color: _isHovering ? Colors.white70 : Colors.white54,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // Album Name (Clickable)
              if (widget.showAlbum)
                Expanded(
                  flex: 4,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        player.navigateTo(
                          'albumDetail',
                          id: widget.song.album.id,
                          meta: widget.song.album,
                        );
                      },
                      child: Text(
                        widget.song.album.name,
                        style: TextStyle(
                          color: _isHovering ? Colors.white54 : Colors.white38,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

              // Duration & Actions
              SizedBox(
                width: 90,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Like button
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 16,
                        color: isLiked ? theme.primaryColor : (_isHovering ? Colors.white54 : Colors.transparent),
                      ),
                      onPressed: () => player.toggleLike(widget.song),
                      tooltip: isLiked ? '取消喜欢' : '喜欢',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    ),

                    // Duration
                    Text(
                      widget.song.durationText,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),

                    const SizedBox(width: 4),

                    // More Menu
                    _buildMoreMenu(player, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(PlayerProvider player, ThemeProvider theme, bool isCurrent) {
    if (isCurrent) {
      return Icon(
        player.isPlaying ? Icons.volume_up_rounded : Icons.pause_rounded,
        size: 16,
        color: theme.primaryColor,
      );
    }
    if (_isHovering) {
      return const Icon(
        Icons.play_arrow_rounded,
        size: 18,
        color: Colors.white70,
      );
    }
    return Text(
      '${widget.index + 1}',
      style: const TextStyle(color: Colors.white38, fontSize: 13),
    );
  }

  Widget _buildMoreMenu(PlayerProvider player, ThemeProvider theme) {
    return PopupMenuButton<String>(
      tooltip: '更多选项',
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 16,
        color: _isHovering ? Colors.white54 : Colors.transparent,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      color: const Color(0xFF1E2028),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      onSelected: (val) {
        switch (val) {
          case 'play':
            player.playSong(widget.song, newQueue: widget.queue, index: widget.index);
            break;
          case 'next':
            player.playNext(widget.song);
            break;
          case 'queue':
            player.addToQueue(widget.song);
            break;
          case 'artist':
            if (widget.song.artists.isNotEmpty) {
              final a = widget.song.artists[0];
              player.navigateTo('artistDetail', id: a.id, meta: a);
            }
            break;
          case 'album':
            player.navigateTo('albumDetail', id: widget.song.album.id, meta: widget.song.album);
            break;
          case 'copy':
            Clipboard.setData(ClipboardData(text: '${widget.song.name} - ${widget.song.artistText}'));
            break;
        }
      },
      itemBuilder: (ctx) => [
        _menuItem('play', '立即播放', Icons.play_arrow_rounded),
        _menuItem('next', '下一首播放', Icons.playlist_play_rounded),
        _menuItem('queue', '加入播放队列', Icons.queue_music_rounded),
        const PopupMenuDivider(height: 1),
        _menuItem('artist', '查看艺人', Icons.person_rounded),
        _menuItem('album', '查看专辑', Icons.album_rounded),
        const PopupMenuDivider(height: 1),
        _menuItem('copy', '复制歌曲信息', Icons.copy_rounded),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
