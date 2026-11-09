import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../components/hover_play_card.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final RustCoreService _core = RustCoreService();

  List<BannerItem> _banners = [];
  List<Playlist> _playlists = [];
  List<Song> _newSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _core.getBanners(),
        _core.getPersonalizedPlaylists(limit: 12),
        _core.getPersonalizedNewsongs(limit: 12),
      ]);

      if (mounted) {
        setState(() {
          _banners = results[0] as List<BannerItem>;
          _playlists = results[1] as List<Playlist>;
          _newSongs = results[2] as List<Song>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 90),
      children: [
        // Banners
        if (_banners.isNotEmpty) ...[
          _buildBanners(),
          const SizedBox(height: 32),
        ],

        // Recommended Playlists
        _buildSectionTitle('推荐歌单', onMore: () {
          context.read<PlayerProvider>().navigateTo('playlistSquare');
        }),
        const SizedBox(height: 14),
        _buildPlaylistsGrid(),

        const SizedBox(height: 32),

        // New Songs
        _buildSectionTitle('最新音乐'),
        const SizedBox(height: 14),
        _buildNewSongsGrid(),
      ],
    );
  }

  Widget _buildBanners() {
    final theme = context.watch<ThemeProvider>();
    final player = context.read<PlayerProvider>();

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _banners.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (ctx, index) {
          final banner = _banners[index];
          return InkWell(
            onTap: () async {
              if (banner.targetId == null || banner.targetId == 0) return;
              if (banner.targetType == 1) {
                // Song
                try {
                  final songs = await _core.getSongDetail([banner.targetId!]);
                  if (songs.isNotEmpty) {
                    player.playSong(songs[0]);
                  }
                } catch (_) {}
              } else if (banner.targetType == 10) {
                // Album
                player.navigateTo('albumDetail', id: banner.targetId!);
              } else if (banner.targetType == 1000) {
                // Playlist
                player.navigateTo('playlistDetail', id: banner.targetId!);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    height: 180,
                    width: 440,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        banner.typeTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onMore}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        if (onMore != null)
          InkWell(
            onTap: onMore,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text('查看更多', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 16),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaylistsGrid() {
    final player = context.read<PlayerProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(4, 7);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 18,
            childAspectRatio: 0.78,
          ),
          itemCount: _playlists.length,
          itemBuilder: (ctx, index) {
            final playlist = _playlists[index];
            return HoverPlayCard(
              title: playlist.name,
              imageUrl: playlist.coverImgUrl,
              playCount: playlist.playCount,
              onTap: () {
                player.navigateTo('playlistDetail', id: playlist.id, meta: playlist);
              },
              onPlay: () async {
                try {
                  final (_, songs) = await _core.getPlaylistDetail(playlist.id);
                  if (songs.isNotEmpty) {
                    player.playSong(songs[0], newQueue: songs, index: 0);
                  }
                } catch (_) {}
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNewSongsGrid() {
    final player = context.read<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 280).floor().clamp(2, 4);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 10,
            mainAxisExtent: 60,
          ),
          itemCount: _newSongs.length,
          itemBuilder: (ctx, index) {
            final song = _newSongs[index];
            final isCurrent = player.currentSong?.id == song.id;

            return InkWell(
              onTap: () {
                player.playSong(song, newQueue: _newSongs, index: index);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.primaryColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrent
                      ? Border.all(color: theme.primaryColor.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: song.album.picUrl,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(color: Colors.white10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.name,
                            style: TextStyle(
                              color: isCurrent ? theme.primaryColor : Colors.white,
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artistText,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isCurrent && player.isPlaying
                          ? Icons.volume_up_rounded
                          : Icons.play_arrow_rounded,
                      color: isCurrent ? theme.primaryColor : Colors.white38,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
