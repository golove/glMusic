<template>
  <div class="app-root" :style="{ '--accent': player.accentColor.value }">
    <!-- Ambient Bokeh Background -->
    <NightBokehBackground />

    <!-- Main App Layout: Sidebar + Detail Content -->
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

// Components
import NightBokehBackground from './components/NightBokehBackground.vue';
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
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeyDown);
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyDown);
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
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", "Plus Jakarta Sans", sans-serif;
  background-color: #121316;
  color: #ffffff;
  -webkit-font-smoothing: antialiased;
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
}

.main-layout {
  position: relative;
  z-index: 1;
  display: flex;
  width: 100%;
  height: 100%;
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
}

.scroll-container::-webkit-scrollbar {
  width: 8px;
}

.scroll-container::-webkit-scrollbar-track {
  background: transparent;
}

.scroll-container::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.15);
  border-radius: 4px;
}

.scroll-container::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.25);
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
