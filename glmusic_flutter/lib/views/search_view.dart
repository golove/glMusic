import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';
import '../components/song_row.dart';
import '../components/hover_play_card.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final RustCoreService _core = RustCoreService();
  final TextEditingController _searchController = TextEditingController();

  List<String> _hotKeywords = [];
  List<String> _recentKeywords = [];
  List<Song> _songResults = [];
  List<Playlist> _playlistResults = [];
  List<Album> _albumResults = [];
  List<Artist> _artistResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  int _selectedTab = 0; // 0: Songs, 1: Playlists, 2: Albums, 3: Artists

  @override
  void initState() {
    super.initState();
    _loadHotKeywords();
    _loadRecentKeywords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentKeywords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('glmusic_recent_searches') ?? [];
      if (mounted) {
        setState(() => _recentKeywords = list);
      }
    } catch (_) {}
  }

  Future<void> _saveRecentKeyword(String keyword) async {
    final list = List<String>.from(_recentKeywords);
    list.remove(keyword);
    list.insert(0, keyword);
    if (list.length > 15) {
      list.removeRange(15, list.length);
    }
    setState(() => _recentKeywords = list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('glmusic_recent_searches', list);
    } catch (_) {}
  }

  Future<void> _clearRecentKeywords() async {
    setState(() => _recentKeywords = []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('glmusic_recent_searches');
    } catch (_) {}
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

    _saveRecentKeyword(trimmed);

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await Future.wait([
        _core.search(trimmed, type: 1, limit: 30),    // Songs
        _core.search(trimmed, type: 1000, limit: 20), // Playlists
        _core.search(trimmed, type: 10, limit: 20),   // Albums
        _core.search(trimmed, type: 100, limit: 20),  // Artists
      ]);

      final rawSongs = (results[0]['songs'] ?? []) as List<dynamic>;
      final songs = rawSongs.map((s) => Song.fromRaw(s as Map<String, dynamic>)).toList();

      final rawPlaylists = (results[1]['playlists'] ?? []) as List<dynamic>;
      final playlists = rawPlaylists.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();

      final rawAlbums = (results[2]['albums'] ?? []) as List<dynamic>;
      final albums = rawAlbums.map((a) => Album.fromJson(a as Map<String, dynamic>)).toList();

      final rawArtists = (results[3]['artists'] ?? []) as List<dynamic>;
      final artists = rawArtists.map((a) => Artist.fromJson(a as Map<String, dynamic>)).toList();

      if (mounted) {
        setState(() {
          _songResults = songs;
          _playlistResults = playlists;
          _albumResults = albums;
          _artistResults = artists;
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
                      hintText: '搜索音乐、歌手、歌单、专辑...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (text) => setState(() {}),
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

          // Recent & Hot Search Chips (if not searched yet)
          if (!_hasSearched) ...[
            if (_recentKeywords.isNotEmpty) ...[
              Row(
                children: [
                  const Text(
                    '最近搜索',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _clearRecentKeywords,
                    child: const Text('清空', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentKeywords.map((kw) {
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 13, color: Colors.white38),
                          const SizedBox(width: 5),
                          Text(kw, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            if (_hotKeywords.isNotEmpty) ...[
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
          ],

          // Search Results
          if (_hasSearched) ...[
            // Tabs: 单曲 / 歌单 / 专辑 / 歌手
            Row(
              children: [
                _buildTabButton('单曲 (${_songResults.length})', 0, theme),
                const SizedBox(width: 10),
                _buildTabButton('歌单 (${_playlistResults.length})', 1, theme),
                const SizedBox(width: 10),
                _buildTabButton('专辑 (${_albumResults.length})', 2, theme),
                const SizedBox(width: 10),
                _buildTabButton('歌手 (${_artistResults.length})', 3, theme),
              ],
            ),
            const SizedBox(height: 14),

            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _buildSelectedTabContent(player),
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

  Widget _buildSelectedTabContent(PlayerProvider player) {
    switch (_selectedTab) {
      case 0:
        return _buildSongResults();
      case 1:
        return _buildPlaylistResults(player);
      case 2:
        return _buildAlbumResults(player);
      case 3:
        return _buildArtistResults(player);
      default:
        return _buildSongResults();
    }
  }

  Widget _buildSongResults() {
    if (_songResults.isEmpty) {
      return const Center(child: Text('无搜索结果', style: TextStyle(color: Colors.white38)));
    }

    return ListView.builder(
      itemCount: _songResults.length,
      itemBuilder: (ctx, index) {
        final song = _songResults[index];
        return SongRow(
          index: index,
          song: song,
          queue: _songResults,
          showAlbum: true,
          showCover: true,
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
            return HoverPlayCard(
              title: pl.name,
              imageUrl: pl.coverImgUrl,
              playCount: pl.playCount,
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
    );
  }

  Widget _buildAlbumResults(PlayerProvider player) {
    if (_albumResults.isEmpty) {
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
          itemCount: _albumResults.length,
          itemBuilder: (ctx, index) {
            final album = _albumResults[index];
            return HoverPlayCard(
              title: album.name,
              subtitle: album.artist?.name,
              imageUrl: album.picUrl,
              onTap: () => player.navigateTo('albumDetail', id: album.id, meta: album),
              onPlay: () async {
                try {
                  final (_, songs) = await _core.getAlbum(album.id);
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

  Widget _buildArtistResults(PlayerProvider player) {
    if (_artistResults.isEmpty) {
      return const Center(child: Text('无搜索结果', style: TextStyle(color: Colors.white38)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(4, 7);

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 18,
            childAspectRatio: 0.82,
          ),
          itemCount: _artistResults.length,
          itemBuilder: (ctx, index) {
            final artist = _artistResults[index];
            return InkWell(
              onTap: () => player.navigateTo('artistDetail', id: artist.id, meta: artist),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  Expanded(
                    child: ClipOval(
                      child: artist.picUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: artist.picUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(color: Colors.white12),
                            )
                          : Container(color: Colors.white12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
