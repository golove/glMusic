import 'dart:io';
import 'package:flutter/material.dart';
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
import 'views/search_view.dart';
import 'views/playlist_detail_view.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Dynamic Bokeh Atmosphere Background
          const Positioned.fill(
            child: NightBokehBackground(),
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
                          // View Switcher
                          Positioned.fill(
                            child: _resolveView(player.currentNav),
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
      case 'search':
        return const SearchView();
      case 'playlistDetail':
        return PlaylistDetailView(
          playlistId: nav.id ?? 0,
          initialPlaylist: nav.meta is Playlist ? nav.meta as Playlist : null,
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
