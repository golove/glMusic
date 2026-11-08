<template>
  <header class="custom-titlebar" data-tauri-drag-region @dblclick="handleDoubleClick">
    <!-- Left: Navigation History Controls & Current Route Breadcrumb -->
    <div class="nav-controls">
      <button
        class="nav-btn"
        :class="{ disabled: !player.canGoBack.value }"
        :disabled="!player.canGoBack.value"
        @click="player.goBack()"
        title="后退 (Alt + ←)"
      >
        <ChevronLeft :size="16" />
      </button>

      <button
        class="nav-btn"
        :class="{ disabled: !player.canGoForward.value }"
        :disabled="!player.canGoForward.value"
        @click="player.goForward()"
        title="前进 (Alt + →)"
      >
        <ChevronRight :size="16" />
      </button>

      <span class="route-name">{{ currentRouteLabel }}</span>
    </div>

    <!-- Center: Drag Region & Playing Status Indicator -->
    <div class="center-drag-area" data-tauri-drag-region>
      <div v-if="player.currentSong.value" class="now-playing-pill" @click="player.isShowingLyrics.value = true">
        <div class="mini-equalizer" v-if="player.isPlaying.value">
          <span class="bar bar-1"></span>
          <span class="bar bar-2"></span>
          <span class="bar bar-3"></span>
        </div>
        <span class="pill-text">{{ player.currentSong.value.name }} - {{ player.currentSong.value.artistText }}</span>
      </div>
      <div v-else class="app-brand-pill">
        <span>glMusic</span>
      </div>
    </div>

    <!-- Right: Performance Mode Switcher & Window Control Buttons -->
    <div class="window-controls">
      <!-- Performance Mode Toggle -->
      <div class="perf-mode-dropdown">
        <button class="perf-btn" @click="togglePerfMenu" :title="`散景动效: ${perfModeLabels[player.bokehPerformanceMode.value]}`">
          <Zap :size="13" />
          <span>{{ perfModeLabels[player.bokehPerformanceMode.value] }}</span>
        </button>
        <div v-if="showPerfMenu" class="perf-menu" @click="showPerfMenu = false">
          <button
            v-for="(label, key) in perfModeLabels"
            :key="key"
            :class="['perf-item', { active: player.bokehPerformanceMode.value === key }]"
            @click="player.setBokehPerformanceMode(key as any)"
          >
            {{ label }}
          </button>
        </div>
      </div>

      <!-- Minimize Button -->
      <button class="win-btn minimize-btn" @click="minimize" title="最小化">
        <Minus :size="14" />
      </button>

      <!-- Maximize / Restore Button -->
      <button class="win-btn maximize-btn" @click="toggleMaximize" :title="player.isMaximized.value ? '还原' : '最大化'">
        <Copy v-if="player.isMaximized.value" :size="12" />
        <Square v-else :size="12" />
      </button>

      <!-- Close Button -->
      <button class="win-btn close-btn" @click="close" title="关闭">
        <X :size="14" />
      </button>
    </div>
  </header>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import {
  ChevronLeft,
  ChevronRight,
  Minus,
  Square,
  Copy,
  X,
  Zap
} from 'lucide-vue-next';
import { player } from '../stores/player';
import { api } from '../services/api';

const showPerfMenu = ref(false);

const perfModeLabels: Record<'full' | 'light' | 'dark', string> = {
  full: '全效光斑',
  light: '轻量节能',
  dark: '极简暗黑'
};

const currentRouteLabel = computed(() => {
  switch (player.currentRoute.value) {
    case 'home': return '发现音乐';
    case 'daily': return '每日推荐';
    case 'playlistSquare': return '歌单广场';
    case 'browse': return '排行榜';
    case 'radio': return '广播电台';
    case 'search': return '音乐搜索';
    case 'history': return '播放历史';
    case 'favorites': return '喜爱音乐';
    case 'playlist': return '歌单详情';
    case 'album': return '专辑详情';
    case 'artist': return '歌手详情';
    default: return 'glMusic';
  }
});

function togglePerfMenu() {
  showPerfMenu.value = !showPerfMenu.value;
}

async function minimize() {
  await api.minimizeWindow();
}

async function toggleMaximize() {
  const max = await api.toggleMaximizeWindow();
  player.isMaximized.value = max;
}

function handleDoubleClick() {
  toggleMaximize();
}

async function close() {
  await api.closeWindow();
}

onMounted(async () => {
  try {
    player.isMaximized.value = await api.isWindowMaximized();
  } catch (e) {
    console.warn('Could not query window maximize state', e);
  }
});
</script>

<style scoped>
.custom-titlebar {
  height: 38px;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 4px 0 16px;
  user-select: none;
  background: rgba(18, 19, 22, 0.94);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  position: relative;
  z-index: 150;
  contain: layout style;
}

/* Left: Navigation Buttons */
.nav-controls {
  display: flex;
  align-items: center;
  gap: 6px;
  width: 240px;
}

.nav-btn {
  background: transparent;
  border: none;
  color: #a1a1aa;
  width: 26px;
  height: 26px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.15s ease;
}

.nav-btn:hover:not(.disabled) {
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
}

.nav-btn.disabled {
  opacity: 0.3;
  cursor: not-allowed;
}

.route-name {
  font-size: 13px;
  font-weight: 600;
  color: #d4d4d8;
  margin-left: 6px;
}

/* Center: Drag Area */
.center-drag-area {
  flex: 1;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: default;
}

.now-playing-pill {
  display: flex;
  align-items: center;
  gap: 8px;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.1);
  padding: 3px 12px;
  border-radius: 12px;
  cursor: pointer;
  transition: background 0.15s ease;
}

.now-playing-pill:hover {
  background: rgba(255, 255, 255, 0.15);
}

.pill-text {
  font-size: 11.5px;
  color: #ffffff;
  max-width: 320px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.mini-equalizer {
  display: flex;
  align-items: flex-end;
  gap: 2px;
  height: 10px;
}

.bar {
  width: 2px;
  background: var(--accent);
  border-radius: 1px;
  animation: barBounce 0.6s infinite alternate;
}

.bar-1 { height: 6px; animation-delay: 0.1s; }
.bar-2 { height: 10px; animation-delay: 0.3s; }
.bar-3 { height: 4px; animation-delay: 0.2s; }

@keyframes barBounce {
  from { height: 3px; }
  to { height: 10px; }
}

.app-brand-pill {
  font-size: 12px;
  font-weight: 700;
  color: #71717a;
  letter-spacing: 0.5px;
}

/* Right: Window Controls */
.window-controls {
  display: flex;
  align-items: center;
  gap: 2px;
}

.perf-mode-dropdown {
  position: relative;
  margin-right: 8px;
}

.perf-btn {
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 6px;
  color: #a1a1aa;
  font-size: 11px;
  padding: 3px 8px;
  display: flex;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.perf-btn:hover {
  background: rgba(255, 255, 255, 0.12);
  color: #ffffff;
}

.perf-menu {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  background: rgba(28, 30, 36, 0.95);
  backdrop-filter: blur(16px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 8px;
  padding: 4px;
  display: flex;
  flex-direction: column;
  gap: 2px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
  z-index: 200;
}

.perf-item {
  background: transparent;
  border: none;
  color: #a1a1aa;
  padding: 6px 14px;
  font-size: 11.5px;
  border-radius: 5px;
  cursor: pointer;
  white-space: nowrap;
  text-align: left;
}

.perf-item:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
}

.perf-item.active {
  color: var(--accent);
  font-weight: 600;
}

.win-btn {
  width: 44px;
  height: 38px;
  background: transparent;
  border: none;
  color: #a1a1aa;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}

.win-btn:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
}

.close-btn:hover {
  background: #e81123 !important;
  color: #ffffff !important;
}
</style>
