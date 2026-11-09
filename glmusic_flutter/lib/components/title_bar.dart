import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/player_provider.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.05),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // On macOS, leave space for traffic lights if frameless
            if (Platform.isMacOS) const SizedBox(width: 72),

            // Back / Forward Navigation buttons
            Row(
              children: [
                _NavButton(
                  icon: Icons.chevron_left_rounded,
                  enabled: player.canGoBack,
                  onTap: player.navigateBack,
                ),
                const SizedBox(width: 4),
                _NavButton(
                  icon: Icons.chevron_right_rounded,
                  enabled: player.canGoForward,
                  onTap: player.navigateForward,
                ),
              ],
            ),

            const SizedBox(width: 16),

            // Current Route Breadcrumb / Search bar shortcut
            Expanded(
              child: Row(
                children: [
                  Text(
                    _resolveRouteTitle(player.currentNav.route),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            // On Windows / Linux: Window controls (Minimize, Maximize, Close)
            if (Platform.isWindows || Platform.isLinux) ...[
              _WindowControlButton(
                icon: Icons.minimize_rounded,
                onTap: () => windowManager.minimize(),
              ),
              _WindowControlButton(
                icon: Icons.crop_square_rounded,
                onTap: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
              _WindowControlButton(
                icon: Icons.close_rounded,
                isClose: true,
                onTap: () => windowManager.close(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _resolveRouteTitle(String route) {
    switch (route) {
      case 'home':
        return '现在就听';
      case 'daily':
        return '每日推荐';
      case 'playlistSquare':
        return '歌单广场';
      case 'browse':
        return '浏览';
      case 'radio':
        return '广播';
      case 'search':
        return '搜索';
      case 'history':
        return '播放历史';
      case 'favorites':
        return '喜欢音乐';
      case 'playlistDetail':
        return '歌单详情';
      case 'albumDetail':
        return '专辑详情';
      case 'artistDetail':
        return '艺人详情';
      default:
        return 'glMusic';
    }
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final bool isClose;
  final VoidCallback onTap;

  const _WindowControlButton({
    required this.icon,
    this.isClose = false,
    required this.onTap,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = widget.isClose
        ? const Color(0xFFE81123)
        : Colors.white.withValues(alpha: 0.1);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 38,
          height: 32,
          alignment: Alignment.center,
          color: _isHovering ? hoverBg : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 14,
            color: _isHovering && widget.isClose ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}
