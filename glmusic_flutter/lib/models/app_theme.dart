import 'package:flutter/material.dart';

enum AppTheme {
  sakura('sakura', '樱花柔粉', 'Sakura Pink', '温柔轻盈 · Apple Music 经典粉质感升华'),
  mint('mint', '薄荷清风', 'Mint Breeze', '通透清凉 · 类似夏日气泡苏打的沉浸感'),
  ocean('ocean', '海风清蓝', 'Sea Breeze', '晴空蔚蓝 · 地中海海风与广袤天际'),
  matcha('matcha', '抹茶初夏', 'Matcha Green', '自然茶香 · 森林系自然治愈与护眼'),
  peach('peach', '蜜桃日落', 'Peach Sunset', '元气甜橙 · 黄昏落日微光与温暖明朗'),
  lavender('lavender', '薰衣草紫', 'Lavender Mist', '梦幻罗兰 · 雅致轻奢、夜间听歌极佳');

  final String key;
  final String label;
  final String englishName;
  final String description;

  const AppTheme(this.key, this.label, this.englishName, this.description);

  Color get primaryColor {
    switch (this) {
      case AppTheme.sakura:
        return const Color(0xFFF43F5E);
      case AppTheme.mint:
        return const Color(0xFF10B981);
      case AppTheme.ocean:
        return const Color(0xFF0EA5E9);
      case AppTheme.matcha:
        return const Color(0xFF16A34A);
      case AppTheme.peach:
        return const Color(0xFFF97316);
      case AppTheme.lavender:
        return const Color(0xFF8B5CF6);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case AppTheme.sakura:
        return const Color(0xFFFB7185);
      case AppTheme.mint:
        return const Color(0xFF06B6D4);
      case AppTheme.ocean:
        return const Color(0xFF3B82F6);
      case AppTheme.matcha:
        return const Color(0xFF84CC16);
      case AppTheme.peach:
        return const Color(0xFFFB923C);
      case AppTheme.lavender:
        return const Color(0xFFA855F7);
    }
  }

  Color get highlightColor {
    switch (this) {
      case AppTheme.sakura:
        return const Color(0xFFFFE0EA); // 晶亮浅樱粉
      case AppTheme.mint:
        return const Color(0xFFB3FFEB); // 晶亮青柠水绿
      case AppTheme.ocean:
        return const Color(0xFFC2F0FF); // 冰晶透蓝
      case AppTheme.matcha:
        return const Color(0xFFEBFAB8); // 晨露嫩黄
      case AppTheme.peach:
        return const Color(0xFFFFEBD4); // 暮色暖金
      case AppTheme.lavender:
        return const Color(0xFFEEDBFF); // 柔光丁香白
    }
  }

  List<Color> get gradientColors => [primaryColor, secondaryColor];

  Color get tintColor => primaryColor.withValues(alpha: 0.12);

  static AppTheme fromKey(String? key) {
    return AppTheme.values.firstWhere(
      (theme) => theme.key == key,
      orElse: () => AppTheme.sakura,
    );
  }
}
