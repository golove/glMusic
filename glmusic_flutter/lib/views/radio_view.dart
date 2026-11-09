import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';
import '../components/hover_play_card.dart';

class RadioView extends StatefulWidget {
  const RadioView({super.key});

  @override
  State<RadioView> createState() => _RadioViewState();
}

class _RadioViewState extends State<RadioView> {
  final RustCoreService _core = RustCoreService();
  List<BannerItem> _banners = [];
  List<Playlist> _radios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRadio();
  }

  Future<void> _loadRadio() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _core.getDjBanners(),
        _core.getDjRecommend(),
      ]);

      if (mounted) {
        setState(() {
          _banners = results[0] as List<BannerItem>;
          _radios = results[1] as List<Playlist>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.read<PlayerProvider>();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 90),
      children: [
        const Text(
          '广播电台',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),

        // DJ Banners (if any)
        if (_banners.isNotEmpty) ...[
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _banners.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (ctx, index) {
                final b = _banners[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: b.imageUrl,
                        height: 160,
                        width: 380,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            b.typeTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
        ],

        // Recommend Stations
        const Text(
          '推荐电台',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
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
              itemCount: _radios.length,
              itemBuilder: (ctx, index) {
                final radio = _radios[index];
                return HoverPlayCard(
                  title: radio.name,
                  subtitle: radio.description,
                  imageUrl: radio.coverImgUrl,
                  playCount: radio.playCount,
                  onTap: () {
                    player.navigateTo('playlistDetail', id: radio.id, meta: radio);
                  },
                  onPlay: () {
                    player.navigateTo('playlistDetail', id: radio.id, meta: radio);
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
