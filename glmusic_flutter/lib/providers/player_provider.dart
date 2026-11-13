import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music.dart';
import '../services/audio_service.dart';
import '../services/rust_core_service.dart';

class NavDestination {
  final String route;
  final int? id;
  final dynamic meta;

  const NavDestination(this.route, {this.id, this.meta});
}

class PlayerProvider extends ChangeNotifier {
  final AudioService _audio = AudioService();
  final RustCoreService _core = RustCoreService();

  Song? _currentSong;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 0.8;
  double _lastVolume = 0.8;
  SoundQuality _soundQuality = SoundQuality.exhigh;
  PlayRepeatMode _repeatMode = PlayRepeatMode.all;
  bool _isShuffled = false;

  List<Song> _queue = [];
  List<Song> _originalQueue = [];
  int _currentIndex = -1;

  List<LyricLine> _lyrics = [];
  int _currentLyricIndex = -1;
  bool _showTranslation = true;

  bool _isShowingLyrics = false;
  bool _isShowingQueue = false;

  final Set<int> _likedSongIds = {};
  List<Song> _history = [];
  List<Song> _favorites = [];

  String? _playbackErrorMessage;
  Timer? _autoSkipTimer;

  // Preloading cache for next song URL
  final Map<int, String> _preloadedUrls = {};
  int? _preloadingSongId;

  // Navigation
  final List<NavDestination> _navStack = [const NavDestination('home')];
  int _navIndex = 0;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  // Getters
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double get volume => _volume;
  bool get isMuted => _volume == 0;
  SoundQuality get soundQuality => _soundQuality;
  PlayRepeatMode get repeatMode => _repeatMode;
  bool get isShuffled => _isShuffled;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  List<LyricLine> get lyrics => _lyrics;
  int get currentLyricIndex => _currentLyricIndex;
  bool get showTranslation => _showTranslation;
  bool get isShowingLyrics => _isShowingLyrics;
  bool get isShowingQueue => _isShowingQueue;
  Set<int> get likedSongIds => _likedSongIds;
  List<Song> get history => _history;
  List<Song> get favorites => _favorites;
  String? get playbackErrorMessage => _playbackErrorMessage;

  NavDestination get currentNav => _navStack[_navIndex];
  bool get canGoBack => _navIndex > 0;
  bool get canGoForward => _navIndex < _navStack.length - 1;

  PlayerProvider() {
    _initAudioListeners();
    _loadInitialData();
  }

  void _initAudioListeners() {
    _posSub = _audio.onPositionChanged.listen((pos) {
      _currentPosition = pos;
      _updateLyricIndex(pos.inMilliseconds / 1000.0);
      _checkPreloadNextSong(pos);
      notifyListeners();
    });

    _durSub = _audio.onDurationChanged.listen((dur) {
      _totalDuration = dur;
      notifyListeners();
    });

    _stateSub = _audio.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });

    _completeSub = _audio.onPlayerComplete.listen((_) {
      _handlePlaybackComplete();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble('glmusic_volume') ?? 0.8;
      _lastVolume = _volume > 0 ? _volume : 0.8;
      _audio.setVolume(_volume);

      final qualityCode = prefs.getString('glmusic_sound_quality');
      if (qualityCode != null) {
        _soundQuality = SoundQuality.values.firstWhere(
          (q) => q.code == qualityCode,
          orElse: () => SoundQuality.exhigh,
        );
      }

      final repeatName = prefs.getString('glmusic_repeat_mode');
      if (repeatName != null) {
        _repeatMode = PlayRepeatMode.values.firstWhere(
          (r) => r.name == repeatName,
          orElse: () => PlayRepeatMode.all,
        );
      }

      _isShuffled = prefs.getBool('glmusic_is_shuffled') ?? false;
      _showTranslation = prefs.getBool('glmusic_show_translation') ?? true;

      _history = await _core.getHistory();
      _favorites = await _core.getFavorites();
      for (final s in _favorites) {
        _likedSongIds.add(s.id);
      }
      notifyListeners();
    } catch (_) {}
  }

  void _checkPreloadNextSong(Duration currentPos) {
    if (_queue.isEmpty || _totalDuration.inSeconds < 25) return;
    if (currentPos.inSeconds < _totalDuration.inSeconds - 12) return;

    final nextIndex = (_currentIndex + 1) % _queue.length;
    final nextSong = _queue[nextIndex];
    if (_preloadedUrls.containsKey(nextSong.id) || _preloadingSongId == nextSong.id) return;

    _preloadingSongId = nextSong.id;
    _core.getSongUrl(
      nextSong.id,
      level: _soundQuality.code,
      name: nextSong.name,
      artist: nextSong.artistText,
      duration: nextSong.duration ~/ 1000,
    ).then((url) {
      if (url != null && url.isNotEmpty) {
        _preloadedUrls[nextSong.id] = url;
      }
      _preloadingSongId = null;
    }).catchError((_) {
      _preloadingSongId = null;
    });
  }

  void _updateLyricIndex(double currentTimeSec) {
    if (_lyrics.isEmpty) return;
    int index = -1;
    for (int i = 0; i < _lyrics.length; i++) {
      if (_lyrics[i].time <= currentTimeSec + 0.15) {
        index = i;
      } else {
        break;
      }
    }
    if (index != _currentLyricIndex) {
      _currentLyricIndex = index;
    }
  }

  void _handlePlaybackComplete() {
    if (_repeatMode == PlayRepeatMode.one) {
      seek(Duration.zero);
      _audio.resume();
      return;
    }
    next();
  }

  Future<void> playSong(Song song, {List<Song>? newQueue, int? index}) async {
    if (newQueue != null) {
      _originalQueue = List.from(newQueue);
      if (_isShuffled) {
        _queue = List.from(newQueue)..shuffle();
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      } else {
        _queue = List.from(newQueue);
        _currentIndex = index ?? _queue.indexWhere((s) => s.id == song.id);
      }
    } else if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    }

    _currentSong = song;
    _isLoading = true;
    _currentPosition = Duration.zero;
    _totalDuration = Duration(milliseconds: song.duration);
    _lyrics = [];
    _currentLyricIndex = -1;
    notifyListeners();

    // Add to history
    _addToHistory(song);

    // Fetch lyrics asynchronously
    _core.getLyric(song.id).then((lines) {
      if (_currentSong?.id == song.id) {
        _lyrics = lines;
        notifyListeners();
      }
    });

    // Fetch playback URL
    try {
      String? url = song.url;
      if (url == null || url.isEmpty) {
        url = _preloadedUrls.remove(song.id);
      }
      if (url == null || url.isEmpty) {
        url = await _core.getSongUrl(
          song.id,
          level: _soundQuality.code,
          name: song.name,
          artist: song.artistText,
          duration: song.duration ~/ 1000,
        );
      }

      if (url != null && url.isNotEmpty) {
        _playbackErrorMessage = null;
        await _audio.playUrl(url);
        _isPlaying = true;
      } else {
        debugPrint('[Player] Failed to get playable URL for ${song.name}');
        _handlePlayFailed(song);
      }
    } catch (e) {
      debugPrint('[Player] Play error: $e');
      _handlePlayFailed(song);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handlePlayFailed(Song song) {
    _playbackErrorMessage = '《${song.name}》暂无可用音源或因版权受限无法播放';
    notifyListeners();

    _autoSkipTimer?.cancel();
    if (_queue.length > 1) {
      _autoSkipTimer = Timer(const Duration(milliseconds: 1600), () {
        _playbackErrorMessage = null;
        next();
      });
    }
  }

  void clearPlaybackError() {
    _playbackErrorMessage = null;
    _autoSkipTimer?.cancel();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null) {
      if (_queue.isNotEmpty) {
        await playSong(_queue[0]);
      }
      return;
    }

    if (_isPlaying) {
      await _audio.pause();
      _isPlaying = false;
    } else {
      await _audio.resume();
      _isPlaying = true;
    }
    notifyListeners();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_currentPosition.inSeconds > 3) {
      // Seek back to start if already played > 3s
      await seek(Duration.zero);
      return;
    }

    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _queue.length - 1;
    }
    _currentIndex = prevIndex;
    await playSong(_queue[_currentIndex]);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    int nextIndex = _currentIndex + 1;
    if (nextIndex >= _queue.length) {
      if (_repeatMode == PlayRepeatMode.off) {
        await _audio.stop();
        _isPlaying = false;
        notifyListeners();
        return;
      }
      nextIndex = 0;
    }
    _currentIndex = nextIndex;
    await playSong(_queue[_currentIndex]);
  }

  Future<void> seek(Duration pos) async {
    _currentPosition = pos;
    await _audio.seek(pos);
    notifyListeners();
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    if (_volume > 0) {
      _lastVolume = _volume;
    }
    await _audio.setVolume(_volume);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('glmusic_volume', _volume);
    } catch (_) {}
  }

  void toggleMute() {
    if (_volume > 0) {
      _lastVolume = _volume;
      setVolume(0.0);
    } else {
      setVolume(_lastVolume > 0 ? _lastVolume : 0.8);
    }
  }

  void toggleTranslation() {
    _showTranslation = !_showTranslation;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('glmusic_show_translation', _showTranslation);
    }).catchError((_) {});
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length || newIndex < 0 || newIndex > _queue.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);

    // Keep original queue synced
    final origIdx = _originalQueue.indexWhere((s) => s.id == song.id);
    if (origIdx >= 0) {
      final origSong = _originalQueue.removeAt(origIdx);
      final newOrigIdx = newIndex.clamp(0, _originalQueue.length);
      _originalQueue.insert(newOrigIdx, origSong);
    }

    if (_currentSong != null) {
      _currentIndex = _queue.indexWhere((s) => s.id == _currentSong!.id);
    }
    notifyListeners();
  }

  void playNext(Song song) {
    if (_queue.isEmpty || _currentIndex < 0) {
      playSong(song);
      return;
    }
    _queue.removeWhere((s) => s.id == song.id);
    _originalQueue.removeWhere((s) => s.id == song.id);
    _queue.insert(_currentIndex + 1, song);
    _originalQueue.insert(_currentIndex + 1, song);
    notifyListeners();
  }

  void addToQueue(Song song) {
    if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      _originalQueue.add(song);
      notifyListeners();
    }
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    final removed = _queue.removeAt(index);
    _originalQueue.removeWhere((s) => s.id == removed.id);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_queue.isNotEmpty) {
        final newIndex = index < _queue.length ? index : 0;
        _currentIndex = newIndex;
        playSong(_queue[_currentIndex]);
      } else {
        _currentSong = null;
        _currentIndex = -1;
        _audio.stop();
        _isPlaying = false;
      }
    }
    notifyListeners();
  }

  void clearQueue() {
    if (_currentSong != null) {
      _queue = [_currentSong!];
      _originalQueue = [_currentSong!];
      _currentIndex = 0;
    } else {
      _queue.clear();
      _originalQueue.clear();
      _currentIndex = -1;
    }
    notifyListeners();
  }

  void setSoundQuality(SoundQuality quality) {
    if (_soundQuality == quality) return;
    _soundQuality = quality;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('glmusic_sound_quality', quality.code);
    }).catchError((_) {});

    if (_currentSong != null && _isPlaying) {
      final pos = _currentPosition;
      playSong(_currentSong!).then((_) => seek(pos));
    }
  }

  void cycleRepeat() {
    switch (_repeatMode) {
      case PlayRepeatMode.all:
        _repeatMode = PlayRepeatMode.one;
        break;
      case PlayRepeatMode.one:
        _repeatMode = PlayRepeatMode.off;
        break;
      case PlayRepeatMode.off:
        _repeatMode = PlayRepeatMode.all;
        break;
    }
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('glmusic_repeat_mode', _repeatMode.name);
    }).catchError((_) {});
  }

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    if (_isShuffled) {
      final current = _currentSong;
      _queue = List.from(_originalQueue)..shuffle();
      if (current != null) {
        _queue.removeWhere((s) => s.id == current.id);
        _queue.insert(0, current);
        _currentIndex = 0;
      }
    } else {
      final current = _currentSong;
      _queue = List.from(_originalQueue);
      if (current != null) {
        _currentIndex = _queue.indexWhere((s) => s.id == current.id);
      }
    }
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('glmusic_is_shuffled', _isShuffled);
    }).catchError((_) {});
  }

  Future<void> toggleLike(Song song) async {
    final isLiked = _likedSongIds.contains(song.id);
    if (isLiked) {
      _likedSongIds.remove(song.id);
      _favorites.removeWhere((s) => s.id == song.id);
    } else {
      _likedSongIds.add(song.id);
      _favorites.removeWhere((s) => s.id == song.id);
      _favorites.insert(0, song);
    }
    notifyListeners();

    try {
      await _core.likeSong(song.id, like: !isLiked);
      await _core.saveFavorites(_favorites);
    } catch (_) {}
  }

  void _addToHistory(Song song) {
    _history.removeWhere((s) => s.id == song.id);
    _history.insert(0, song);
    if (_history.length > 200) {
      _history = _history.sublist(0, 200);
    }
    _core.saveHistory(_history);
  }

  void clearHistory() {
    _history.clear();
    _core.saveHistory([]);
    notifyListeners();
  }

  void toggleLyrics([bool? show]) {
    _isShowingLyrics = show ?? !_isShowingLyrics;
    notifyListeners();
  }

  void toggleQueue([bool? show]) {
    _isShowingQueue = show ?? !_isShowingQueue;
    notifyListeners();
  }

  // Navigation
  void navigateTo(String route, {int? id, dynamic meta}) {
    if (_navIndex < _navStack.length - 1) {
      _navStack.removeRange(_navIndex + 1, _navStack.length);
    }
    _navStack.add(NavDestination(route, id: id, meta: meta));
    _navIndex = _navStack.length - 1;
    notifyListeners();
  }

  void navigateBack() {
    if (canGoBack) {
      _navIndex--;
      notifyListeners();
    }
  }

  void navigateForward() {
    if (canGoForward) {
      _navIndex++;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }
}
