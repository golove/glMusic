import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/music.dart';

class RustCoreService {
  static final RustCoreService _instance = RustCoreService._internal();
  factory RustCoreService() => _instance;
  RustCoreService._internal();

  static const String _host = '127.0.0.1';
  static const int _port = 19980;
  static const String baseUrl = 'http://$_host:$_port/api';

  Process? _coreProcess;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Check if the service is already running
    final isAlive = await ping();
    if (!isAlive) {
      await _startCoreProcess();
    }
    _isInitialized = true;
  }

  Future<bool> ping() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(milliseconds: 1500));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startCoreProcess() async {
    // Try multiple possible paths for the glmusic-core binary
    final execDir = File(Platform.resolvedExecutable).parent.path;
    final List<String> candidatePaths = [
      if (Platform.isWindows) ...[
        '$execDir/glmusic-core.exe',
        '$execDir/data/glmusic-core.exe',
        'rust/target/release/glmusic-core.exe',
        'rust/target/debug/glmusic-core.exe',
        '../rust/target/release/glmusic-core.exe',
      ] else if (Platform.isMacOS) ...[
        '$execDir/glmusic-core',
        '$execDir/../Resources/glmusic-core',
        'rust/target/release/glmusic-core',
        'rust/target/debug/glmusic-core',
        '../rust/target/release/glmusic-core',
      ] else ...[
        '$execDir/glmusic-core',
        'rust/target/release/glmusic-core',
      ],
    ];

    String? foundPath;
    for (final p in candidatePaths) {
      if (File(p).existsSync()) {
        foundPath = p;
        break;
      }
    }

    if (foundPath != null) {
      try {
        debugPrint('[RustCore] Starting process: $foundPath');
        _coreProcess = await Process.start(foundPath, [], environment: {
          'PORT': '$_port',
        });
        _coreProcess!.stdout.transform(utf8.decoder).listen((data) {
          debugPrint('[glmusic-core stdout] $data');
        });
        _coreProcess!.stderr.transform(utf8.decoder).listen((data) {
          debugPrint('[glmusic-core stderr] $data');
        });

        // Wait up to 5 seconds for ping to succeed
        for (int i = 0; i < 25; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (await ping()) {
            debugPrint('[RustCore] Core process is up and running on port $_port!');
            return;
          }
        }
      } catch (e) {
        debugPrint('[RustCore] Failed to start $foundPath: $e');
      }
    } else {
      debugPrint('[RustCore] glmusic-core binary not found in candidates, assuming external daemon or dev server.');
    }
  }

  void dispose() {
    _coreProcess?.kill();
    _coreProcess = null;
  }

  // --- API methods ---

  Future<dynamic> _get(String path, [Map<String, dynamic>? queryParams]) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
    );
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }

  // Banners
  Future<List<BannerItem>> getBanners() async {
    try {
      final json = await _get('/banner');
      final list = (json['banners'] ?? []) as List<dynamic>;
      return list.map((b) => BannerItem.fromJson(b as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getBanners error: $e');
      return [];
    }
  }

  // Personalized Playlists ("推荐歌单")
  Future<List<Playlist>> getPersonalizedPlaylists({int limit = 10}) async {
    try {
      final json = await _get('/personalized', {'limit': limit});
      final list = (json['result'] ?? []) as List<dynamic>;
      return list.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getPersonalizedPlaylists error: $e');
      return [];
    }
  }

  // Personalized New Songs ("最新音乐")
  Future<List<Song>> getPersonalizedNewsongs({int limit = 12}) async {
    try {
      final json = await _get('/personalized/newsong', {'limit': limit});
      final list = (json['result'] ?? []) as List<dynamic>;
      return list.map((item) {
        final songData = (item['song'] ?? item) as Map<String, dynamic>;
        return Song.fromRaw(songData);
      }).toList();
    } catch (e) {
      debugPrint('getPersonalizedNewsongs error: $e');
      return [];
    }
  }

  // Daily Recommend Songs ("每日推荐")
  Future<List<Song>> getDailyRecommendSongs() async {
    try {
      final json = await _get('/recommend/songs');
      final data = json['data'] ?? json;
      final dailySongs = (data['dailySongs'] ?? data['recommend'] ?? []) as List<dynamic>;
      return dailySongs.map((s) => Song.fromRaw(s as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getDailyRecommendSongs error: $e');
      return [];
    }
  }

  // Top Charts / Toplists ("排行榜")
  Future<List<Playlist>> getToplists() async {
    try {
      final json = await _get('/toplist');
      final list = (json['list'] ?? []) as List<dynamic>;
      return list.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getToplists error: $e');
      return [];
    }
  }

  // Top Playlists by Category ("歌单广场")
  Future<List<Playlist>> getTopPlaylists({String cat = '全部', int limit = 30, int offset = 0}) async {
    try {
      final json = await _get('/top/playlist', {
        'cat': cat,
        'limit': limit,
        'offset': offset,
      });
      final list = (json['playlists'] ?? []) as List<dynamic>;
      return list.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getTopPlaylists error: $e');
      return [];
    }
  }

  // Playlist Detail + Track list
  Future<(Playlist, List<Song>)> getPlaylistDetail(int id) async {
    try {
      final json = await _get('/playlist/detail', {'id': id});
      final playlistRaw = (json['playlist'] ?? {}) as Map<String, dynamic>;
      final playlist = Playlist.fromJson(playlistRaw);

      final trackList = (playlistRaw['tracks'] ?? []) as List<dynamic>;
      List<Song> songs = trackList.map((t) => Song.fromRaw(t as Map<String, dynamic>)).toList();

      if (songs.isEmpty) {
        // Fetch track list separately
        final tracksJson = await _get('/playlist/tracks', {'id': id, 'limit': 100, 'offset': 0});
        final songsRaw = (tracksJson['songs'] ?? []) as List<dynamic>;
        songs = songsRaw.map((s) => Song.fromRaw(s as Map<String, dynamic>)).toList();
      }

      return (playlist, songs);
    } catch (e) {
      debugPrint('getPlaylistDetail error: $e');
      rethrow;
    }
  }

  // Album Detail + Songs
  Future<(Album, List<Song>)> getAlbum(int id) async {
    try {
      final json = await _get('/album', {'id': id});
      final albumRaw = (json['album'] ?? {}) as Map<String, dynamic>;
      final album = Album.fromJson(albumRaw);
      final songsRaw = (json['songs'] ?? []) as List<dynamic>;
      final songs = songsRaw.map((s) => Song.fromRaw(s as Map<String, dynamic>)).toList();
      return (album, songs);
    } catch (e) {
      debugPrint('getAlbum error: $e');
      rethrow;
    }
  }

  // Song Detail
  Future<List<Song>> getSongDetail(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final json = await _get('/song/detail', {'ids': ids.join(',')});
      final songsRaw = (json['songs'] ?? []) as List<dynamic>;
      return songsRaw.map((s) => Song.fromRaw(s as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getSongDetail error: $e');
      return [];
    }
  }

  // Song Playback URL
  Future<String?> getSongUrl(int id, {String level = 'exhigh'}) async {
    try {
      final json = await _get('/song/url', {'id': id, 'level': level});
      final data = (json['data'] ?? []) as List<dynamic>;
      if (data.isNotEmpty) {
        final url = data[0]['url'] as String?;
        if (url != null && url.isNotEmpty) {
          // Force https for netease cdn if needed
          return url.startsWith('http://') ? url.replaceFirst('http://', 'https://') : url;
        }
      }
      return null;
    } catch (e) {
      debugPrint('getSongUrl error: $e');
      return null;
    }
  }

  // Song Lyrics parsed into LyricLine
  Future<List<LyricLine>> getLyric(int id) async {
    try {
      final json = await _get('/lyric', {'id': id});
      final lrc = json['lrc']?['lyric'] as String? ?? '';
      final tlyric = json['tlyric']?['lyric'] as String? ?? '';

      return _parseLyrics(lrc, tlyric);
    } catch (e) {
      debugPrint('getLyric error: $e');
      return [];
    }
  }

  List<LyricLine> _parseLyrics(String mainLrc, String transLrc) {
    final Map<int, String> transMap = {};
    if (transLrc.isNotEmpty) {
      for (final line in transLrc.split('\n')) {
        final trimmed = line.trim();
        final match = RegExp(r'^\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)$').firstMatch(trimmed);
        if (match != null) {
          final m = int.parse(match.group(1)!);
          final s = int.parse(match.group(2)!);
          final msStr = match.group(3) ?? '00';
          final ms = int.parse(msStr.padRight(3, '0').substring(0, 3));
          final timeMs = m * 60000 + s * 1000 + ms;
          final text = match.group(4)?.trim() ?? '';
          if (text.isNotEmpty) {
            transMap[timeMs ~/ 100] = text;
          }
        }
      }
    }

    final List<LyricLine> result = [];
    for (final line in mainLrc.split('\n')) {
      final trimmed = line.trim();
      final match = RegExp(r'^\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)$').firstMatch(trimmed);
      if (match != null) {
        final m = int.parse(match.group(1)!);
        final s = int.parse(match.group(2)!);
        final msStr = match.group(3) ?? '00';
        final ms = int.parse(msStr.padRight(3, '0').substring(0, 3));
        final timeSec = m * 60.0 + s + (ms / 1000.0);
        final text = match.group(4)?.trim() ?? '';
        final timeKey = (m * 60000 + s * 1000 + ms) ~/ 100;
        final trans = transMap[timeKey];

        if (text.isNotEmpty) {
          result.add(LyricLine(time: timeSec, text: text, translation: trans));
        }
      }
    }

    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  // Search
  Future<Map<String, dynamic>> search(String keywords, {int type = 1, int limit = 30, int offset = 0}) async {
    try {
      final json = await _get('/search', {
        'keywords': keywords,
        'stype': type,
        'limit': limit,
        'offset': offset,
      });
      return json['result'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      debugPrint('search error: $e');
      return {};
    }
  }

  // Hot Search Keywords
  Future<List<String>> getHotSearch() async {
    try {
      final json = await _get('/search/hot');
      final data = (json['data'] ?? json['result']?['hots'] ?? []) as List<dynamic>;
      return data.map((d) => (d['searchWord'] ?? d['first'] ?? '') as String).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      debugPrint('getHotSearch error: $e');
      return ['周杰伦', '林俊杰', '陈奕迅', 'Taylor Swift', '王菲', '陶喆'];
    }
  }

  // Artist Detail + Hot Songs
  Future<Map<String, dynamic>> getArtistDetail(int id) async {
    try {
      final json = await _get('/artist/detail', {'id': id});
      return json as Map<String, dynamic>;
    } catch (e) {
      debugPrint('getArtistDetail error: $e');
      return {};
    }
  }

  // Artist Albums
  Future<List<Album>> getArtistAlbums(int id, {int limit = 30}) async {
    try {
      final json = await _get('/artist/album', {'id': id, 'limit': limit});
      final list = (json['hotAlbums'] ?? []) as List<dynamic>;
      return list.map((a) => Album.fromJson(a as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getArtistAlbums error: $e');
      return [];
    }
  }

  // DJ Radio
  Future<List<BannerItem>> getDjBanners() async {
    try {
      final json = await _get('/dj/banner');
      final list = (json['data'] ?? []) as List<dynamic>;
      return list.map((b) => BannerItem.fromJson(b as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Playlist>> getDjRecommend() async {
    try {
      final json = await _get('/dj/recommend');
      final list = (json['djRadios'] ?? []) as List<dynamic>;
      return list.map((d) {
        return Playlist(
          id: (d['id'] as num?)?.toInt() ?? 0,
          name: d['name'] as String? ?? '电台',
          coverImgUrl: (d['picUrl'] ?? '') as String,
          description: d['rcmdtext'] as String?,
          playCount: (d['playCount'] as num?)?.toInt(),
          trackCount: (d['programCount'] as num?)?.toInt(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // QR Code Login
  Future<String> getQrKey() async {
    final json = await _get('/login/qr/key');
    return (json['data']?['unikey'] ?? '') as String;
  }

  Future<String> createQrUrl(String key) async {
    final json = await _get('/login/qr/create', {'key': key});
    return (json['data']?['qrurl'] ?? json['data']?['qrimg'] ?? '') as String;
  }

  Future<Map<String, dynamic>> checkQrStatus(String key) async {
    final json = await _get('/login/qr/check', {'key': key});
    return json as Map<String, dynamic>;
  }

  Future<UserProfile?> getLoginStatus() async {
    try {
      final json = await _get('/login/status');
      final profile = json['data']?['profile'] ?? json['profile'];
      if (profile != null) {
        return UserProfile.fromJson(profile as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _post('/logout');
    } catch (_) {}
  }

  // User Playlists
  Future<List<Playlist>> getUserPlaylists(int uid, {int limit = 50, int offset = 0}) async {
    try {
      final json = await _get('/user/playlist', {'uid': uid, 'limit': limit, 'offset': offset});
      final list = (json['playlist'] ?? []) as List<dynamic>;
      return list.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getUserPlaylists error: $e');
      return [];
    }
  }

  // Like Song
  Future<bool> likeSong(int id, {bool like = true}) async {
    try {
      final json = await _get('/like', {'id': id, 'like': like});
      return json['code'] == 200;
    } catch (e) {
      debugPrint('likeSong error: $e');
      return false;
    }
  }

  Future<List<int>> getLikeList(int uid) async {
    try {
      final json = await _get('/likelist', {'uid': uid});
      final ids = (json['ids'] ?? []) as List<dynamic>;
      return ids.map((id) => (id as num).toInt()).toList();
    } catch (e) {
      return [];
    }
  }

  // Persistence: History & Favorites
  Future<List<Song>> getHistory() async {
    try {
      final json = await _get('/history');
      final list = (json['songs'] ?? []) as List<dynamic>;
      return list.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveHistory(List<Song> songs) async {
    try {
      await _post('/history', {'songs': songs.map((s) => s.toJson()).toList()});
    } catch (_) {}
  }

  Future<List<Song>> getFavorites() async {
    try {
      final json = await _get('/favorites');
      final list = (json['songs'] ?? []) as List<dynamic>;
      return list.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveFavorites(List<Song> songs) async {
    try {
      await _post('/favorites', {'songs': songs.map((s) => s.toJson()).toList()});
    } catch (_) {}
  }
}
