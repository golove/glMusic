<template>
  <div class="view-container">
    <div class="header-section">
      <h1 class="view-title">浏览</h1>
      <p class="view-subtitle">官方权威音乐排行榜与全球热歌风向标</p>
    </div>

    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>正在加载榜单...</span>
    </div>

    <div v-else class="content-section">
      <h2 class="section-title">排行榜</h2>

      <div class="toplist-grid">
        <div
          v-for="item in toplists"
          :key="item.id"
          class="toplist-card"
          @click="player.navigate('playlist', item.id)"
        >
          <div class="card-cover">
            <img :src="item.coverImgUrl" alt="" loading="lazy" />
            <button
              class="hover-play-btn"
              @click.stop="playPlaylistDirectly(item.id)"
              title="播放榜单"
            >
              <Play :size="15" fill="#ffffff" style="margin-left: 2px;" />
            </button>
            <div class="count-tag" v-if="item.playCount">
              <Headphones :size="11" />
              <span>{{ formatPlayCount(item.playCount) }}</span>
            </div>
          </div>
          <div class="card-info">
            <div class="card-title" :title="item.name">{{ item.name }}</div>
            <div class="card-desc">{{ item.description || '网易云官方排行榜' }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Play, Headphones, Loader2 } from 'lucide-vue-next';
import { api } from '../services/api';
import { player } from '../stores/player';
import type { Playlist } from '../types/music';

const toplists = ref<Playlist[]>([]);
const isLoading = ref(true);

onMounted(async () => {
  try {
    const list = await api.getToplist();
    toplists.value = list;
  } catch (e) {
    console.error('Failed to load toplist', e);
  } finally {
    isLoading.value = false;
  }
});

async function playPlaylistDirectly(playlistId: number) {
  try {
    const songs = await api.getPlaylistTracks(playlistId, 50);
    if (songs && songs.length > 0) {
      player.play(songs[0], songs);
    }
  } catch (e) {
    console.error('Play playlist error', e);
  }
}

function formatPlayCount(count: number): string {
  if (count > 100000000) return `${(count / 100000000).toFixed(1)}亿`;
  if (count > 10000) return `${Math.floor(count / 10000)}万`;
  return count.toString();
}
</script>

<style scoped>
.view-container {
  padding: 30px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 28px;
}

.header-section {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.view-title {
  margin: 0;
  font-size: 32px;
  font-weight: 800;
  color: #ffffff;
  letter-spacing: -0.5px;
}

.view-subtitle {
  margin: 0;
  font-size: 13px;
  color: #71717a;
}

.content-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.section-title {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: #ffffff;
}

.loading-state {
  height: 260px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  color: #71717a;
  font-size: 13.5px;
}

.spin-icon {
  animation: spin 1s linear infinite;
  color: var(--accent);
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.toplist-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(170px, 1fr));
  gap: 22px;
}

.toplist-card {
  display: flex;
  flex-direction: column;
  gap: 8px;
  cursor: pointer;
}

.card-cover {
  position: relative;
  width: 100%;
  aspect-ratio: 1 / 1;
  border-radius: 10px;
  overflow: hidden;
  background: #1e2026;
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.35);
  transition: transform 0.22s ease, box-shadow 0.22s ease;
}

.toplist-card:hover .card-cover {
  transform: scale(1.03);
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.5);
}

.card-cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.hover-play-btn {
  position: absolute;
  bottom: 10px;
  right: 10px;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: var(--accent);
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
  opacity: 0;
  transform: scale(0.85);
  transition: all 0.18s cubic-bezier(0.2, 0.8, 0.2, 1);
}

.toplist-card:hover .hover-play-btn {
  opacity: 1;
  transform: scale(1);
}

.hover-play-btn:hover {
  transform: scale(1.1) !important;
}

.count-tag {
  position: absolute;
  top: 8px;
  right: 8px;
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 2px 7px;
  border-radius: 10px;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(6px);
  color: #ffffff;
  font-size: 10.5px;
  font-weight: 500;
}

.card-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.card-title {
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  line-height: 1.35;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-desc {
  font-size: 11px;
  color: #71717a;
  line-height: 1.4;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>