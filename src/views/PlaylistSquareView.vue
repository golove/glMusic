<template>
  <div class="view-container">
    <div class="header-section">
      <h2 class="view-title">歌单广场</h2>
      <p class="view-subtitle">浏览精选官方与高品质分类歌单</p>

      <!-- Category Filter Pills -->
      <div class="categories-row">
        <button
          v-for="cat in categories"
          :key="cat"
          :class="['cat-pill', { active: currentCat === cat }]"
          @click="changeCategory(cat)"
        >
          {{ cat }}
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>正在加载歌单...</span>
    </div>

    <!-- Playlists Grid -->
    <div v-else class="playlist-grid">
      <div
        v-for="item in playlists"
        :key="item.id"
        class="playlist-card"
        @click="player.navigate('playlist', item.id)"
      >
        <div class="cover-box">
          <img :src="item.coverImgUrl" class="cover-img" alt="" loading="lazy" />
          <div class="play-overlay">
            <Play :size="24" fill="#fff" />
          </div>
          <div class="play-count" v-if="item.playCount">
            <Headphones :size="12" />
            <span>{{ formatPlayCount(item.playCount) }}</span>
          </div>
        </div>
        <div class="playlist-name" :title="item.name">{{ item.name }}</div>
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

const categories = [
  '全部', '华语', '欧美', '流行', '摇滚', '民谣', '电子', '轻音乐', '影视原声', 'ACG', '说唱'
];

const currentCat = ref('全部');
const playlists = ref<Playlist[]>([]);
const isLoading = ref(true);

onMounted(() => {
  loadPlaylists();
});

async function loadPlaylists() {
  isLoading.value = true;
  try {
    const list = await api.getTopPlaylists(currentCat.value, 48);
    playlists.value = list;
  } catch (e) {
    console.error('Failed to load playlists', e);
  } finally {
    isLoading.value = false;
  }
}

function changeCategory(cat: string) {
  if (currentCat.value === cat) return;
  currentCat.value = cat;
  loadPlaylists();
}

function formatPlayCount(count: number): string {
  if (count > 100000000) return `${(count / 100000000).toFixed(1)}亿`;
  if (count > 10000) return `${Math.floor(count / 10000)}万`;
  return count.toString();
}
</script>

<style scoped>
.view-container {
  padding: 32px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 28px;
}

.header-section {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.view-title {
  margin: 0;
  font-size: 28px;
  font-weight: 800;
  color: #ffffff;
}

.view-subtitle {
  margin: 0;
  font-size: 13px;
  color: #71717a;
}

.categories-row {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 4px;
  scrollbar-width: none;
}

.cat-pill {
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: rgba(255, 255, 255, 0.05);
  border-radius: 16px;
  color: #a1a1aa;
  font-size: 13px;
  padding: 5px 14px;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.15s ease;
}

.cat-pill:hover {
  background: rgba(255, 255, 255, 0.12);
  color: #ffffff;
}

.cat-pill.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #ffffff;
  font-weight: 600;
}

.loading-state {
  height: 300px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  color: #71717a;
}

.playlist-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(170px, 1fr));
  gap: 24px;
}

.playlist-card {
  display: flex;
  flex-direction: column;
  gap: 8px;
  cursor: pointer;
}

.cover-box {
  position: relative;
  width: 100%;
  aspect-ratio: 1;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.4);
  background: rgba(255, 255, 255, 0.05);
}

.cover-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.25s ease;
}

.playlist-card:hover .cover-img {
  transform: scale(1.06);
}

.play-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: opacity 0.2s ease;
}

.playlist-card:hover .play-overlay {
  opacity: 1;
}

.play-count {
  position: absolute;
  top: 8px;
  right: 8px;
  background: rgba(0, 0, 0, 0.65);
  backdrop-filter: blur(6px);
  padding: 2px 7px;
  border-radius: 10px;
  font-size: 10.5px;
  color: #ffffff;
  display: flex;
  align-items: center;
  gap: 4px;
}

.playlist-name {
  font-size: 13.5px;
  font-weight: 500;
  color: #e4e4e7;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4;
}

.spin-icon {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
