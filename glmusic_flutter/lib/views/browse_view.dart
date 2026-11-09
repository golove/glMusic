import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../services/rust_core_service.dart';
import '../components/hover_play_card.dart';

class BrowseView extends StatefulWidget {
  const BrowseView({super.key});

  @override
  State<BrowseView> createState() => _BrowseViewState();
}

class _BrowseViewState extends State<BrowseView> {
  final RustCoreService _core = RustCoreService();
  List<Playlist> _toplists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadToplists();
  }

  Future<void> _loadToplists() async {
    setState(() => _isLoading = true);
    try {
      final list = await _core.getToplists();
      if (mounted) {
        setState(() {
          _toplists = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final officialCharts = _toplists.take(4).toList();
    final globalCharts = _toplists.skip(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 90),
      children: [
        const Text(
          '官方榜单',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),

        // Official charts (Top 4)
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: officialCharts.length,
              itemBuilder: (ctx, index) {
                final pl = officialCharts[index];
                return HoverPlayCard(
                  title: pl.name,
                  subtitle: pl.description,
                  imageUrl: pl.coverImgUrl,
                  onTap: () => player.navigateTo('playlistDetail', id: pl.id, meta: pl),
                  onPlay: () async {
                    try {
                      final (_, songs) = await _core.getPlaylistDetail(pl.id);
                      if (songs.isNotEmpty) {
                        player.playSong(songs[0], newQueue: songs, index: 0);
                      }
                    } catch (_) {}
                  },
                );
              },
            );
          },
        ),

        const SizedBox(height: 32),

        const Text(
          '全球榜单',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),

        // Global charts grid
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(4, 7);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              itemCount: globalCharts.length,
              itemBuilder: (ctx, index) {
                final pl = globalCharts[index];
                return HoverPlayCard(
                  title: pl.name,
                  imageUrl: pl.coverImgUrl,
                  onTap: () => player.navigateTo('playlistDetail', id: pl.id, meta: pl),
                  onPlay: () async {
                    try {
                      final (_, songs) = await _core.getPlaylistDetail(pl.id);
                      if (songs.isNotEmpty) {
                        player.playSong(songs[0], newQueue: songs, index: 0);
                      }
                    } catch (_) {}
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
