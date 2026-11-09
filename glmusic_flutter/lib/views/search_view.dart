import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> with SingleTickerProviderStateMixin {
  final RustCoreService _core = RustCoreService();
  final TextEditingController _searchController = TextEditingController();

  List<String> _hotKeywords = [];
  List<Song> _songResults = [];
  List<Playlist> _playlistResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  int _selectedTab = 0; // 0: Songs, 1: Playlists

  @override
  void initState() {
    super.initState();
    _loadHotKeywords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHotKeywords() async {
    final list = await _core.getHotSearch();
    if (mounted) {
      setState(() => _hotKeywords = list);
    }
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      // Search songs (type: 1)
      final songsRes = await _core.search(trimmed, type: 1, limit: 30);
      final rawSongs = (songsRes['songs'] ?? []) as List<dynamic>;
      final songs = rawSongs.map((s) => Song.fromRaw(s as Map<String, dynamic>)).toList();

      // Search playlists (type: 1000)
      final plRes = await _core.search(trimmed, type: 1000, limit: 20);
      final rawPlaylists = (plRes['playlists'] ?? []) as List<dynamic>;
      final playlists = rawPlaylists.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();

      if (mounted) {
        setState(() {
          _songResults = songs;
          _playlistResults = playlists;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: theme.primaryColor,
                    decoration: const InputDecoration(
                      hintText: '搜索音乐、歌手、歌单...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                const SizedBox(width: 6),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Hot Search Chips (if not searched yet)
          if (!_hasSearched && _hotKeywords.isNotEmpty) ...[
            const Text(
              '热门搜索',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hotKeywords.map((kw) {
                return InkWell(
                  onTap: () {
                    _searchController.text = kw;
                    _performSearch(kw);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      kw,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Search Results
          if (_hasSearched) ...[
            // Tabs: 单曲 / 歌单
            Row(
              children: [
                _buildTabButton('单曲 (${_songResults.length})', 0, theme),
                const SizedBox(width: 12),
                _buildTabButton('歌单 (${_playlistResults.length})', 1, theme),
              ],
            ),
            const SizedBox(height: 14),

            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedTab == 0
                      ? _buildSongResults(player, theme)
                      : _buildPlaylistResults(player),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, ThemeProvider theme) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: theme.primaryColor) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.primaryColor : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSongResults(PlayerProvider player, ThemeProvider theme) {
    if (_songResults.isEmpty) {
      return const Center(child: Text('无搜索结果', style: TextStyle(color: Colors.white38)));
    }

    return ListView.builder(
      itemCount: _songResults.length,
      itemBuilder: (ctx, index) {
        final song = _songResults[index];
        final isCurrent = player.currentSong?.id == song.id;

        return InkWell(
          onTap: () => player.playSong(song, newQueue: _songResults, index: index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrent ? theme.primaryColor.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: isCurrent && player.isPlaying
                      ? Icon(Icons.volume_up_rounded, size: 16, color: theme.primaryColor)
                      : Text('${index + 1}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: song.album.picUrl,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(color: Colors.white10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Text(
                    song.name,
                    style: TextStyle(
                      color: isCurrent ? theme.primaryColor : Colors.white,
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    song.artistText,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    song.album.name,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(song.durationText, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistResults(PlayerProvider player) {
    if (_playlistResults.isEmpty) {
      return const Center(child: Text('无搜索结果', style: TextStyle(color: Colors.white38)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(4, 7);

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.78,
          ),
          itemCount: _playlistResults.length,
          itemBuilder: (ctx, index) {
            final pl = _playlistResults[index];
            return InkWell(
              onTap: () => player.navigateTo('playlistDetail', id: pl.id, meta: pl),
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: pl.coverImgUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pl.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
