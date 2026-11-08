<template>
  <aside class="sidebar-container">
    <!-- Brand / App Header -->
    <div class="sidebar-header">
      <img src="/logo.png" alt="glMusic" class="app-logo" />
      <div class="header-text">
        <h1 class="app-title">glMusic</h1>
        <span class="app-badge">Apple Music Style</span>
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
          <PlayCircle class="nav-icon" :size="17" />
          <span>现在就听</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'daily' }]"
          @click="player.navigate('daily')"
        >
          <Calendar class="nav-icon" :size="17" />
          <span>每日推荐</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'playlistSquare' }]"
          @click="player.navigate('playlistSquare')"
        >
          <LayoutGrid class="nav-icon" :size="17" />
          <span>歌单广场</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'browse' }]"
          @click="player.navigate('browse')"
        >
          <Compass class="nav-icon" :size="17" />
          <span>浏览</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'radio' }]"
          @click="player.navigate('radio')"
        >
          <Radio class="nav-icon" :size="17" />
          <span>广播</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'search' }]"
          @click="player.navigate('search')"
        >
          <Search class="nav-icon" :size="17" />
          <span>搜索</span>
        </button>
      </div>

      <!-- Section: 资料库 -->
      <div class="nav-section">
        <div class="section-title">资料库</div>
        <button
          :class="['nav-item', { active: player.currentRoute.value === 'history' }]"
          @click="player.navigate('history')"
        >
          <Clock class="nav-icon" :size="17" />
          <span>播放历史</span>
          <span class="count-pill" v-if="player.history.value.length > 0">{{ player.history.value.length }}</span>
        </button>

        <button
          :class="['nav-item', { active: player.currentRoute.value === 'favorites' }]"
          @click="player.navigate('favorites')"
        >
          <Heart class="nav-icon" :size="17" />
          <span>喜爱音乐</span>
          <span class="count-pill" v-if="player.favorites.value.length > 0">{{ player.favorites.value.length }}</span>
        </button>
      </div>
    </div>

    <!-- Sidebar Footer / User Profile & Themes (Aligned with Mac version) -->
    <div class="sidebar-footer">
      <!-- Theme Switcher Pill -->
      <div class="theme-bar">
        <button class="theme-pill-btn" @click="showThemeMenu = !showThemeMenu" title="切换应用配色主题">
          <span class="theme-indicator" :style="{ backgroundColor: player.currentTheme.value.primaryColor }"></span>
          <span class="theme-name">{{ player.currentTheme.value.name }}</span>
          <Palette :size="13" class="theme-icon" />
        </button>

        <!-- Theme Selection Popover -->
        <div v-if="showThemeMenu" class="theme-popover" @click="showThemeMenu = false">
          <div class="popover-title">选择视觉主题</div>
          <div class="theme-options">
            <button
              v-for="item in APP_THEMES"
              :key="item.id"
              :class="['theme-option-card', { active: player.currentThemeId.value === item.id }]"
              @click="player.setTheme(item.id)"
            >
              <span class="swatch" :style="{ backgroundColor: item.primaryColor }"></span>
              <span class="label">{{ item.name }}</span>
            </button>
          </div>
        </div>
      </div>

      <!-- User Profile Card -->
      <div v-if="player.currentUser.value" class="user-card logged-in">
        <img
          :src="player.currentUser.value.avatarUrl"
          class="user-avatar"
          alt="Avatar"
        />
        <div class="user-info">
          <span class="user-name" :title="player.currentUser.value.nickname">{{ player.currentUser.value.nickname }}</span>
          <span class="user-sub">网易云音乐</span>
        </div>
        <button class="logout-btn" @click.stop="handleLogout" title="退出登录">
          <LogOut :size="14" />
        </button>
      </div>

      <!-- Not Logged In: Tap to login -->
      <div v-else class="user-card not-logged" @click="player.isShowingLoginModal.value = true">
        <div class="avatar-placeholder">
          <User :size="16" />
        </div>
        <div class="user-info">
          <span class="user-name">登录网易云</span>
          <span class="user-sub">同步歌单与收藏</span>
        </div>
        <ChevronRight :size="14" class="arrow-icon" />
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import {
  PlayCircle,
  Calendar,
  LayoutGrid,
  Compass,
  Radio,
  Search,
  Clock,
  Heart,
  Palette,
  User,
  LogOut,
  ChevronRight
} from 'lucide-vue-next';
import { player, APP_THEMES } from '../stores/player';
import { api } from '../services/api';

const showThemeMenu = ref(false);

async function handleLogout() {
  await api.logout();
  player.currentUser.value = null;
  player.likedSongIds.value.clear();
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
  padding: 22px 18px 14px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.app-logo {
  width: 34px;
  height: 34px;
  border-radius: 9px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
}

.header-text {
  display: flex;
  flex-direction: column;
}

.app-title {
  margin: 0;
  font-size: 18px;
  font-weight: 700;
  color: #ffffff;
  letter-spacing: -0.4px;
}

.app-badge {
  font-size: 9.5px;
  color: #8e8e93;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.sidebar-nav {
  flex: 1;
  overflow-y: auto;
  padding: 6px 12px;
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.nav-section {
  display: flex;
  flex-direction: column;
  gap: 2px;
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
  padding: 7px 11px;
  border-radius: 8px;
  border: none;
  background: transparent;
  color: #a1a1aa;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.16s cubic-bezier(0.2, 0.8, 0.2, 1);
  text-align: left;
  width: 100%;
}

.nav-item:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #ffffff;
}

.nav-item.active {
  background: var(--accent, #f43f5e);
  color: #ffffff;
  font-weight: 600;
  box-shadow: 0 4px 14px color-mix(in srgb, var(--accent) 35%, transparent);
}

.nav-item.active .nav-icon {
  color: #ffffff;
}

.nav-icon {
  flex-shrink: 0;
  color: var(--accent, #f43f5e);
  transition: color 0.15s ease;
}

.nav-item.active .nav-icon {
  color: #ffffff;
}

.count-pill {
  margin-left: auto;
  font-size: 10.5px;
  font-weight: 600;
  padding: 1px 7px;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.1);
  color: #d4d4d8;
}

.nav-item.active .count-pill {
  background: rgba(255, 255, 255, 0.25);
  color: #ffffff;
}

/* Sidebar Footer */
.sidebar-footer {
  padding: 10px 12px 14px;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
  display: flex;
  flex-direction: column;
  gap: 10px;
  position: relative;
}

/* Theme Switcher */
.theme-bar {
  position: relative;
  width: 100%;
}

.theme-pill-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 6px 10px;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.04);
  color: #d4d4d8;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.theme-pill-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  border-color: rgba(255, 255, 255, 0.14);
}

.theme-indicator {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
  box-shadow: 0 0 6px var(--accent);
}

.theme-name {
  flex: 1;
  text-align: left;
  font-weight: 500;
}

.theme-icon {
  color: #71717a;
}

.theme-popover {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 0;
  right: 0;
  background: rgba(28, 30, 36, 0.96);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 12px;
  padding: 10px;
  box-shadow: 0 12px 30px rgba(0, 0, 0, 0.5);
  z-index: 100;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.popover-title {
  font-size: 11px;
  font-weight: 600;
  color: #71717a;
  padding: 0 4px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.theme-options {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 6px;
}

.theme-option-card {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 8px;
  border-radius: 6px;
  border: 1px solid transparent;
  background: rgba(255, 255, 255, 0.04);
  color: #e4e4e7;
  font-size: 11.5px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.theme-option-card:hover {
  background: rgba(255, 255, 255, 0.1);
}

.theme-option-card.active {
  background: rgba(255, 255, 255, 0.12);
  border-color: var(--accent);
}

.theme-option-card .swatch {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

/* User Card */
.user-card {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 7px 9px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
  cursor: pointer;
  transition: all 0.18s ease;
}

.user-card:hover {
  background: rgba(255, 255, 255, 0.07);
}

.user-avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  object-fit: cover;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.avatar-placeholder {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.08);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #a1a1aa;
}

.user-info {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}

.user-name {
  font-size: 12px;
  font-weight: 600;
  color: #ffffff;
  white-space: nowrap;
  text-overflow: ellipsis;
  overflow: hidden;
}

.user-sub {
  font-size: 10px;
  color: #71717a;
  white-space: nowrap;
  text-overflow: ellipsis;
  overflow: hidden;
}

.logout-btn {
  background: transparent;
  border: none;
  color: #71717a;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.15s ease;
}

.logout-btn:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
}

.arrow-icon {
  color: #52525b;
}
</style>