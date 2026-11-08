<template>
  <aside class="sidebar-container">
    <!-- Brand / App Header -->
    <div class="sidebar-header">
      <img src="/logo.png" alt="glMusic" class="app-logo" />
      <div class="header-text">
        <h1 class="app-title">glMusic</h1>
        <span class="app-badge">Rust Native</span>
      </div>
    </div>

    <!-- Navigation List -->
    <div class="sidebar-nav">
      <!-- Section: 探索 -->
      <div class="nav-section">
        <div class="section-title">探索</div>
        <button
          :class="['nav-item', { active: player.currentRoute.value === 'home' }]"
          @click="player.navigate('home')"
        >
          <Compass class="nav-icon" :size="18" />
          <span>发现音乐</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'daily' }]"
          @click="player.navigate('daily')"
        >
          <Sparkles class="nav-icon" :size="18" />
          <span>每日推荐</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'playlistSquare' }]"
          @click="player.navigate('playlistSquare')"
        >
          <LayoutGrid class="nav-icon" :size="18" />
          <span>歌单广场</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'browse' }]"
          @click="player.navigate('browse')"
        >
          <Trophy class="nav-icon" :size="18" />
          <span>排行榜</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'radio' }]"
          @click="player.navigate('radio')"
        >
          <Radio class="nav-icon" :size="18" />
          <span>广播电台</span>
        </button>
      </div>

      <!-- Section: 我的音乐 -->
      <div class="nav-section">
        <div class="section-title">我的音乐</div>
        <button
          :class="['nav-item', { active: player.currentRoute.value === 'search' }]"
          @click="player.navigate('search')"
        >
          <Search class="nav-icon" :size="18" />
          <span>音乐搜索</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'favorites' }]"
          @click="player.navigate('favorites')"
        >
          <Heart class="nav-icon" :size="18" />
          <span>喜爱音乐</span>
          <span class="count-pill">{{ player.favorites.value.length }}</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'history' }]"
          @click="player.navigate('history')"
        >
          <History class="nav-icon" :size="18" />
          <span>播放历史</span>
          <span class="count-pill">{{ player.history.value.length }}</span>
        </button>
      </div>
    </div>

    <!-- Sidebar Footer / User Profile & Themes -->
    <div class="sidebar-footer">
      <!-- Theme Colors Selector -->
      <div class="theme-colors">
        <span class="theme-label">主题</span>
        <div class="color-dots">
          <button
            v-for="color in themePresets"
            :key="color"
            class="color-dot"
            :style="{ backgroundColor: color, outline: player.accentColor.value === color ? '2px solid #ffffff' : 'none' }"
            @click="player.setAccentColor(color)"
          ></button>
        </div>
      </div>

      <!-- User Card -->
      <div class="user-card" @click="handleUserClick">
        <img
          :src="player.currentUser.value?.avatarUrl || 'https://p1.music.126.net/SUeqMM8JaU4StopCSdUJnQ==/109951165647004069.jpg'"
          class="user-avatar"
          alt="Avatar"
        />
        <div class="user-info">
          <span class="user-name">{{ player.currentUser.value?.nickname || '未登录' }}</span>
          <span class="user-status">{{ player.currentUser.value ? '网易云已连接' : '点击扫码登录' }}</span>
        </div>
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
import {
  Compass,
  Sparkles,
  LayoutGrid,
  Trophy,
  Radio,
  Search,
  Heart,
  History
} from 'lucide-vue-next';
import { player } from '../stores/player';

const themePresets = [
  '#0071e3', // Apple Blue
  '#fa233b', // Apple Music Red
  '#a259ff', // Royal Purple
  '#30d158', // Neon Green
  '#ff9500', // Sunset Orange
];

function handleUserClick() {
  if (!player.currentUser.value) {
    player.isShowingLoginModal.value = true;
  }
}
</script>

<style scoped>
.sidebar-container {
  width: 220px;
  height: 100%;
  display: flex;
  flex-direction: column;
  background: rgba(20, 22, 27, 0.90);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  border-right: 1px solid rgba(255, 255, 255, 0.08);
  user-select: none;
  z-index: 10;
  contain: layout style;
}

.sidebar-header {
  padding: 24px 18px 16px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.app-logo {
  width: 36px;
  height: 36px;
  border-radius: 9px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
}

.header-text {
  display: flex;
  flex-direction: column;
}

.app-title {
  margin: 0;
  font-size: 19px;
  font-weight: 700;
  color: #ffffff;
  letter-spacing: -0.4px;
}

.app-badge {
  font-size: 10px;
  color: #8e8e93;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.sidebar-nav {
  flex: 1;
  overflow-y: auto;
  padding: 8px 12px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.nav-section {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.section-title {
  font-size: 11px;
  font-weight: 600;
  color: #71717a;
  text-transform: uppercase;
  letter-spacing: 0.6px;
  padding: 6px 10px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  border-radius: 8px;
  border: none;
  background: transparent;
  color: #a1a1aa;
  font-size: 13.5px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.18s cubic-bezier(0.2, 0.8, 0.2, 1);
  text-align: left;
  width: 100%;
}

.nav-item:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #ffffff;
}

.nav-item.active {
  background: var(--accent, #0071e3);
  color: #ffffff;
  font-weight: 600;
  box-shadow: 0 4px 14px rgba(0, 113, 227, 0.35);
}

.nav-icon {
  flex-shrink: 0;
}

.count-pill {
  margin-left: auto;
  font-size: 11px;
  padding: 2px 6px;
  background: rgba(255, 255, 255, 0.12);
  border-radius: 10px;
  color: #d4d4d8;
}

.sidebar-footer {
  padding: 16px;
  border-top: 1px solid rgba(255, 255, 255, 0.07);
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.theme-colors {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 4px;
}

.theme-label {
  font-size: 11px;
  color: #71717a;
  font-weight: 500;
}

.color-dots {
  display: flex;
  gap: 7px;
}

.color-dot {
  width: 14px;
  height: 14px;
  border-radius: 50%;
  border: none;
  cursor: pointer;
  transition: transform 0.15s ease;
}

.color-dot:hover {
  transform: scale(1.2);
}

.user-card {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 8px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.18s ease;
}

.user-card:hover {
  background: rgba(255, 255, 255, 0.06);
}

.user-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  object-fit: cover;
  border: 1px solid rgba(255, 255, 255, 0.15);
}

.user-info {
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.user-name {
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  white-space: nowrap;
  text-overflow: ellipsis;
  overflow: hidden;
}

.user-status {
  font-size: 11px;
  color: #71717a;
}
</style>
