<template>
  <div class="view-container">
    <div class="header-section">
      <h2 class="view-title">排行榜</h2>
      <p class="view-subtitle">云音乐官方权威权威音乐排行榜</p>
    </div>

    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>正在加载榜单...</span>
    </div>

    <div v-else class="toplist-grid">
      <div
        v-for="item in toplists"
        :key="item.id"
        class="toplist-card"
        @click="player.navigate('playlist', item.id)"
      >
        <div class="card-cover">
          <img :src="item.coverImgUrl" alt="" loading="lazy" />
          <div class="play-overlay">
            <Play :size="24" fill="#fff" />
          </div>
          <div class="count-tag" v-if="item.playCount">
            <Headphones :size="12" />
            <span>{{ formatPlayCount(item.playCount) }}</span>
          </div>
        </div>
        <div class="card-info">
          <h4 class="card-title">{{ item.name }}</h4>
          <p class="card-desc">{{ item.description || '网易云官方排行榜' }}</p>
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
  gap: 6px;
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

.loading-state {
  height: 300px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  color: #71717a;
}

.toplist-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 20px;
}

.toplist-card {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 12px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.06);
  cursor: pointer;
  transition: all 0.2s ease;
}

.toplist-card:hover {
  background: rgba(255, 255, 255, 0.1);
  transform: translateY(-2px);
}

.card-cover {
  position: relative;
  width: 76px;
  height: 76px;
  border-radius: 10px;
  overflow: hidden;
  flex-shrink: 0;
}

.card-cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
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

.toplist-card:hover .play-overlay {
  opacity: 1;
}

.count-tag {
  position: absolute;
  bottom: 4px;
  right: 4px;
  background: rgba(0, 0, 0, 0.65);
  backdrop-filter: blur(4px);
  padding: 1px 5px;
  border-radius: 8px;
  font-size: 9.5px;
  color: #ffffff;
  display: flex;
  align-items: center;
  gap: 3px;
}

.card-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  gap: 4px;
}

.card-title {
  margin: 0;
  font-size: 15px;
  font-weight: 700;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-desc {
  margin: 0;
  font-size: 12px;
  color: #71717a;
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
