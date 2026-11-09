import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/app_theme.dart';
import '../models/music.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/rust_core_service.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final RustCoreService _core = RustCoreService();
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final profile = await _core.getLoginStatus();
    if (mounted && profile != null) {
      setState(() => _userProfile = profile);
    }
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _QrLoginDialog(
        onSuccess: (profile) {
          setState(() => _userProfile = profile);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final currentRoute = player.currentNav.route;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo & App Name Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: theme.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'glMusic',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Main Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              children: [
                _NavItem(
                  title: '现在就听',
                  icon: Icons.play_circle_fill_rounded,
                  isSelected: currentRoute == 'home',
                  onTap: () => player.navigateTo('home'),
                ),
                _NavItem(
                  title: '每日推荐',
                  icon: Icons.calendar_today_rounded,
                  isSelected: currentRoute == 'daily',
                  onTap: () => player.navigateTo('daily'),
                ),
                _NavItem(
                  title: '歌单广场',
                  icon: Icons.grid_view_rounded,
                  isSelected: currentRoute == 'playlistSquare',
                  onTap: () => player.navigateTo('playlistSquare'),
                ),
                _NavItem(
                  title: '浏览',
                  icon: Icons.explore_rounded,
                  isSelected: currentRoute == 'browse',
                  onTap: () => player.navigateTo('browse'),
                ),
                _NavItem(
                  title: '广播',
                  icon: Icons.radio_rounded,
                  isSelected: currentRoute == 'radio',
                  onTap: () => player.navigateTo('radio'),
                ),
                _NavItem(
                  title: '搜索',
                  icon: Icons.search_rounded,
                  isSelected: currentRoute == 'search',
                  onTap: () => player.navigateTo('search'),
                ),

                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    '资料库',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _NavItem(
                  title: '播放历史',
                  icon: Icons.history_rounded,
                  isSelected: currentRoute == 'history',
                  onTap: () => player.navigateTo('history'),
                ),
                _NavItem(
                  title: '喜欢音乐',
                  icon: Icons.favorite_rounded,
                  isSelected: currentRoute == 'favorites',
                  onTap: () => player.navigateTo('favorites'),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            color: Colors.white.withValues(alpha: 0.08),
            height: 1,
            indent: 12,
            endIndent: 12,
          ),

          // User Card & Theme Switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                _buildUserCard(),
                const SizedBox(height: 8),
                _ThemePickerButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    if (_userProfile != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: _userProfile!.avatarUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.person, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userProfile!.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    '网易云音乐',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white38),
              onPressed: () async {
                await _core.logout();
                setState(() => _userProfile = null);
              },
              tooltip: '退出登录',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showLoginDialog,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white12,
                child: Icon(Icons.person_rounded, size: 16, color: Colors.white70),
              ),
              SizedBox(width: 10),
              Text(
                '登录网易云',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? theme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: theme.primaryColor.withValues(alpha: 0.3), width: 0.8)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? theme.primaryColor : Colors.white60,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePickerButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final current = themeProvider.currentTheme;

    return PopupMenuButton<AppTheme>(
      tooltip: '切换主题',
      offset: const Offset(0, -220),
      color: const Color(0xFF1E2028),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      onSelected: (theme) => themeProvider.setTheme(theme),
      itemBuilder: (ctx) => AppTheme.values.map((t) {
        final isSelected = t == current;
        return PopupMenuItem<AppTheme>(
          value: t,
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: t.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.label,
                style: TextStyle(
                  color: isSelected ? t.primaryColor : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check, size: 16, color: t.primaryColor),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: themeProvider.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              current.label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrLoginDialog extends StatefulWidget {
  final ValueChanged<UserProfile> onSuccess;
  const _QrLoginDialog({required this.onSuccess});

  @override
  State<_QrLoginDialog> createState() => _QrLoginDialogState();
}

class _QrLoginDialogState extends State<_QrLoginDialog> {
  final RustCoreService _core = RustCoreService();
  String? _qrImg;
  String? _unikey;
  String _statusMessage = '正在生成二维码...';
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _startQrFlow();
  }

  Future<void> _startQrFlow() async {
    try {
      final key = await _core.getQrKey();
      _unikey = key;
      final url = await _core.createQrUrl(key);
      setState(() {
        _qrImg = url;
        _statusMessage = '请使用网易云音乐 App 扫码登录';
      });
      _startPolling();
    } catch (e) {
      setState(() => _statusMessage = '二维码生成失败，请重试');
    }
  }

  void _startPolling() async {
    _isChecking = true;
    while (_isChecking && mounted && _unikey != null) {
      await Future.delayed(const Duration(seconds: 3));
      if (!_isChecking || !mounted) break;

      try {
        final res = await _core.checkQrStatus(_unikey!);
        final code = res['code'] as int? ?? 0;
        if (code == 800) {
          setState(() => _statusMessage = '二维码已过期，请刷新');
          break;
        } else if (code == 802) {
          setState(() => _statusMessage = '已扫码，请在手机上点击确认');
        } else if (code == 803) {
          setState(() => _statusMessage = '登录成功，正在加载...');
          final profile = await _core.getLoginStatus();
          if (profile != null) {
            widget.onSuccess(profile);
          }
          break;
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _isChecking = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2028),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '扫码登录网易云音乐',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _qrImg != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _qrImg!,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
