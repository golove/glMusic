<template>
  <div
    class="app-root"
    :class="{ 'is-maximized': player.isMaximized.value }"
    :style="{
      '--accent': player.accentColor.value,
      '--accent-secondary': player.secondaryColor.value,
      '--accent-highlight': player.highlightColor.value
    }"
  >
    <!-- Ambient Bokeh Background -->
    <NightBokehBackground />

    <!-- Window Shell -->
    <div class="window-shell">
      <!-- Top Custom TitleBar with Navigation, Brand & Window Controls -->
      <TitleBar />

      <!-- Main Layout: Sidebar + Detail Content -->
      <div class="main-layout">
        <Sidebar />

        <main class="content-area">
          <!-- Scrollable Detail View -->
          <div class="scroll-container">
            <component :is="currentViewComponent" />
          </div>

          <!-- Floating Apple Music Style Capsule PlayerBar -->
          <div class="floating-player-bar">
            <PlayerBar />
          </div>
        </main>
      </div>
    </div>

    <!-- Fullscreen Synced Lyrics Overlay -->
    <LyricsView v-if="player.isShowingLyrics.value" />

    <!-- Queue Slide-over Drawer -->
    <QueueDrawer />

    <!-- NetEase Cloud QR Login Modal -->
    <LoginModal />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted } from 'vue';
import { player } from './stores/player';
import { api } from './services/api';

// Components
import NightBokehBackground from './components/NightBokehBackground.vue';
import TitleBar from './components/TitleBar.vue';
import Sidebar from './components/Sidebar.vue';
import PlayerBar from './components/PlayerBar.vue';
import LyricsView from './components/LyricsView.vue';
import QueueDrawer from './components/QueueDrawer.vue';
import LoginModal from './components/LoginModal.vue';

// Views
import HomeView from './views/HomeView.vue';
import DailyRecommendView from './views/DailyRecommendView.vue';
import PlaylistSquareView from './views/PlaylistSquareView.vue';
import BrowseView from './views/BrowseView.vue';
import RadioView from './views/RadioView.vue';
import SearchView from './views/SearchView.vue';
import HistoryView from './views/HistoryView.vue';
import FavoritesView from './views/FavoritesView.vue';
import PlaylistDetailView from './views/PlaylistDetailView.vue';
import AlbumDetailView from './views/AlbumDetailView.vue';
import ArtistDetailView from './views/ArtistDetailView.vue';

const currentViewComponent = computed(() => {
  switch (player.currentRoute.value) {
    case 'home': return HomeView;
    case 'daily': return DailyRecommendView;
    case 'playlistSquare': return PlaylistSquareView;
    case 'browse': return BrowseView;
    case 'radio': return RadioView;
    case 'search': return SearchView;
    case 'history': return HistoryView;
    case 'favorites': return FavoritesView;
    case 'playlist': return PlaylistDetailView;
    case 'album': return AlbumDetailView;
    case 'artist': return ArtistDetailView;
    default: return HomeView;
  }
});

// Global keyboard shortcuts
function handleKeyDown(e: KeyboardEvent) {
  // If user is typing in an input, don't trigger global shortcuts
  if ((e.target as HTMLElement).tagName === 'INPUT' || (e.target as HTMLElement).tagName === 'TEXTAREA') {
    return;
  }

  if (e.code === 'Space') {
    e.preventDefault();
    player.togglePlay();
  } else if (e.altKey && e.code === 'ArrowLeft') {
    e.preventDefault();
    player.goBack();
  } else if (e.altKey && e.code === 'ArrowRight') {
    e.preventDefault();
    player.goForward();
  } else if ((e.ctrlKey || e.metaKey) && e.code === 'ArrowRight') {
    e.preventDefault();
    player.next();
  } else if ((e.ctrlKey || e.metaKey) && e.code === 'ArrowLeft') {
    e.preventDefault();
    player.previous();
  } else if ((e.ctrlKey || e.metaKey) && e.code === 'ArrowUp') {
    e.preventDefault();
    player.setVolume(Math.min(1, player.volume.value + 0.05));
  } else if ((e.ctrlKey || e.metaKey) && e.code === 'ArrowDown') {
    e.preventDefault();
    player.setVolume(Math.max(0, player.volume.value - 0.05));
  } else if (e.key === 'Escape') {
    if (player.isShowingLyrics.value) {
      player.isShowingLyrics.value = false;
    } else if (player.isShowingQueue.value) {
      player.isShowingQueue.value = false;
    } else if (player.isShowingLoginModal.value) {
      player.isShowingLoginModal.value = false;
    }
  }
}

let resizeDebounceTimer: ReturnType<typeof setTimeout> | null = null;

function handleWindowResize() {
  if (!document.body.classList.contains('is-resizing')) {
    document.body.classList.add('is-resizing');
  }

  if (resizeDebounceTimer) {
    clearTimeout(resizeDebounceTimer);
  }

  resizeDebounceTimer = setTimeout(async () => {
    document.body.classList.remove('is-resizing');
    try {
      player.isMaximized.value = await api.isWindowMaximized();
    } catch {
      // ignore
    }
  }, 100);
}

onMounted(async () => {
  window.addEventListener('keydown', handleKeyDown);
  window.addEventListener('resize', handleWindowResize, { passive: true });
  try {
    player.isMaximized.value = await api.isWindowMaximized();
  } catch {
    // ignore
  }
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyDown);
  window.removeEventListener('resize', handleWindowResize);
  if (resizeDebounceTimer) {
    clearTimeout(resizeDebounceTimer);
  }
});
</script>

<style>
@import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap');

* {
  box-sizing: border-box;
}

html, body {
  margin: 0;
  padding: 0;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI Variable Display", "Segoe UI Variable Text", "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei UI", "Microsoft YaHei", "Plus Jakarta Sans", sans-serif;
  background-color: #121316;
  color: #ffffff;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
}

#app {
  width: 100%;
  height: 100%;
}

.app-root {
  width: 100%;
  height: 100%;
  position: relative;
  display: flex;
  overflow: hidden;
  border-radius: 8px;
  background-color: #121316;
}

.app-root.is-maximized {
  border-radius: 0;
}

.window-shell {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  overflow: hidden;
}

.main-layout {
  flex: 1;
  display: flex;
  width: 100%;
  height: calc(100% - 38px);
  overflow: hidden;
}

.content-area {
  flex: 1;
  height: 100%;
  position: relative;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.scroll-container {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  contain: content;
}

/* Window Drag-Resize Performance Optimization (Turbo Mode) */
body.is-resizing * {
  transition: none !important;
  animation-play-state: paused !important;
}

body.is-resizing .night-bokeh-container .bokeh-spot {
  transition: none !important;
  will-change: auto !important;
}

body.is-resizing .sidebar-container,
body.is-resizing .custom-titlebar,
body.is-resizing .player-bar-capsule,
body.is-resizing .nav-item,
body.is-resizing .banner-badge {
  backdrop-filter: none !important;
  -webkit-backdrop-filter: none !important;
}

body.is-resizing .floating-player-bar {
  pointer-events: none !important;
}

/* Custom ultra-thin Apple-style frosted scrollbars for Windows */
.scroll-container::-webkit-scrollbar {
  width: 6px;
}

.scroll-container::-webkit-scrollbar-track {
  background: transparent;
}

.scroll-container::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.16);
  border-radius: 3px;
  transition: background 0.2s ease;
}

.scroll-container::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.32);
}

.floating-player-bar {
  position: absolute;
  bottom: 16px;
  left: 0;
  right: 0;
  padding: 0 130px;
  pointer-events: none;
  z-index: 99;
}

.floating-player-bar > * {
  pointer-events: auto;
}

@media (max-width: 1200px) {
  .floating-player-bar {
    padding: 0 40px;
  }
}
</style>
