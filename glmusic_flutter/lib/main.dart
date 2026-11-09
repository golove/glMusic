import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'models/music.dart';
import 'providers/player_provider.dart';
import 'providers/theme_provider.dart';
import 'services/rust_core_service.dart';

import 'components/night_bokeh_background.dart';
import 'components/title_bar.dart';
import 'components/sidebar.dart';
import 'components/player_bar.dart';
import 'components/lyrics_overlay.dart';
import 'components/queue_drawer.dart';

import 'views/home_view.dart';
import 'views/daily_recommend_view.dart';
import 'views/playlist_square_view.dart';
import 'views/browse_view.dart';
import 'views/radio_view.dart';
import 'views/search_view.dart';
import 'views/playlist_detail_view.dart';
import 'views/album_detail_view.dart';
import 'views/artist_detail_view.dart';
import 'views/history_view.dart';
import 'views/favorites_view.dart';

class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    return client;
  }
}

void main() async {
  HttpOverrides.global = AppHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Limit in-memory image cache to avoid memory bloat
  PaintingBinding.instance.imageCache.maximumSizeBytes = 128 * 1024 * 1024; // 128 MB
  PaintingBinding.instance.imageCache.maximumSize = 300;

  // Desktop window configuration
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1160, 780),
      minimumSize: Size(980, 640),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'glMusic',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize Rust backend service
  RustCoreService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: const GLMusicApp(),
    ),
  );
}

class GLMusicApp extends StatelessWidget {
  const GLMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'glMusic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        primaryColor: theme.primaryColor,
        colorScheme: ColorScheme.dark(
          primary: theme.primaryColor,
          secondary: theme.secondaryColor,
          surface: const Color(0xFF181A20),
        ),
        fontFamily: Platform.isWindows ? 'Microsoft YaHei' : 'PingFang SC',
        useMaterial3: true,
        // Apple style sleek scrollbars
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)) {
              return Colors.white.withValues(alpha: 0.35);
            }
            return Colors.white.withValues(alpha: 0.15);
          }),
          radius: const Radius.circular(8),
          thickness: WidgetStateProperty.all(6),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    // Global desktop shortcuts
    return CallbackShortcuts(
      bindings: {
        // Space -> Toggle Play / Pause
        const SingleActivator(LogicalKeyboardKey.space): () {
          // Only if not focused on text field
          final focus = FocusManager.instance.primaryFocus;
          if (focus == null || focus.context?.widget is! EditableText) {
            player.togglePlayPause();
          }
        },
        // Cmd/Ctrl + Right -> Next Track
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true): player.next,
        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true): player.next,
        // Cmd/Ctrl + Left -> Prev Track
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true): player.previous,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true): player.previous,
        // Cmd/Ctrl + Up -> Volume Up
        const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): () {
          player.setVolume((player.volume + 0.05).clamp(0.0, 1.0));
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): () {
          player.setVolume((player.volume + 0.05).clamp(0.0, 1.0));
        },
        // Cmd/Ctrl + Down -> Volume Down
        const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): () {
          player.setVolume((player.volume - 0.05).clamp(0.0, 1.0));
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): () {
          player.setVolume((player.volume - 0.05).clamp(0.0, 1.0));
        },
        // Cmd/Ctrl + L -> Toggle Lyrics
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): player.toggleLyrics,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): player.toggleLyrics,
        // Esc -> Close lyrics or queue
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (player.isShowingLyrics) {
            player.toggleLyrics(false);
          } else if (player.isShowingQueue) {
            player.toggleQueue(false);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // 1. Dynamic Bokeh Atmosphere Background with RepaintBoundary isolation
              const Positioned.fill(
                child: RepaintBoundary(
                  child: NightBokehBackground(),
                ),
              ),

              // 2. Main Window Layout
              Column(
                children: [
                  // Top Title Bar & Window Drag Header
                  const TitleBar(),

                  // Body: Sidebar + Dynamic Content
                  Expanded(
                    child: Row(
                      children: [
                        // Sidebar
                        const Sidebar(),

                        // Main Content Canvas
                        Expanded(
                          child: Stack(
                            children: [
                              // View Switcher with smooth subtle cross-fade
                              Positioned.fill(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: KeyedSubtree(
                                    key: ValueKey('${player.currentNav.route}_${player.currentNav.id ?? 0}'),
                                    child: _resolveView(player.currentNav),
                                  ),
                                ),
                              ),

                              // Floating Apple Music Player Bar Capsule
                              const Align(
                                alignment: Alignment.bottomCenter,
                                child: PlayerBar(),
                              ),

                              // Queue Drawer Popover
                              const QueueDrawer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 3. Fullscreen Synced Lyrics Overlay
              const LyricsOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resolveView(NavDestination nav) {
    switch (nav.route) {
      case 'home':
        return const HomeView();
      case 'daily':
        return const DailyRecommendView();
      case 'playlistSquare':
        return const PlaylistSquareView();
      case 'browse':
        return const BrowseView();
      case 'radio':
        return const RadioView();
      case 'search':
        return const SearchView();
      case 'playlistDetail':
        return PlaylistDetailView(
          playlistId: nav.id ?? 0,
          initialPlaylist: nav.meta is Playlist ? nav.meta as Playlist : null,
        );
      case 'albumDetail':
        return AlbumDetailView(
          albumId: nav.id ?? 0,
          initialAlbum: nav.meta is Album ? nav.meta as Album : null,
        );
      case 'artistDetail':
        return ArtistDetailView(
          artistId: nav.id ?? 0,
          initialArtist: nav.meta is Artist ? nav.meta as Artist : null,
        );
      case 'history':
        return const HistoryView();
      case 'favorites':
        return const FavoritesView();
      default:
        return const HomeView();
    }
  }
}
