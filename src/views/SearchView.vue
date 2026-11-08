<template>
  <div class="view-container">
    <div class="search-header">
      <div class="search-box">
        <Search class="search-icon" :size="18" />
        <input
          v-model="keyword"
          class="search-input"
          placeholder="搜索歌曲、歌手、专辑..."
          @keyup.enter="handleSearch"
        />
        <button v-if="keyword" class="clear-btn" @click="keyword = ''">
          <X :size="16" />
        </button>
      </div>

      <!-- Hot Search Tags -->
      <div v-if="hotKeywords.length > 0 && results.length === 0" class="hot-search-section">
        <span class="hot-title">大家都在搜:</span>
        <div class="hot-tags">
          <button
            v-for="word in hotKeywords.slice(0, 10)"
            :key="word"
            class="hot-pill"
            @click="searchWord(word)"
          >
            {{ word }}
          </button>
        </div>
      </div>
    </div>

    <!-- Results Section -->
    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>正在搜索...</span>
    </div>

    <div v-else-if="results.length > 0" class="results-container">
      <div class="results-header">
        <span class="results-count">找到 {{ results.length }} 首单曲</span>
        <button class="play-all-btn" @click="playAllResults">
          <Play :size="14" fill="#fff" />
          <span>播放全部</span>
        </button>
      </div>

      <div class="song-table">
        <div class="table-header">
          <span class="col-index">#</span>
          <span class="col-title">标题</span>
          <span class="col-album">专辑</span>
          <span class="col-actions">操作</span>
          <span class="col-duration">时长</span>
        </div>

        <div
          v-for="(song, idx) in results"
          :key="song.id"
          :class="['table-row', { active: player.currentSong.value?.id === song.id }]"
          @click="player.play(song, results)"
        >
          <span class="col-index">{{ idx + 1 }}</span>
          <div class="col-title song-title-cell">
            <img :src="song.album.picUrl" class="cell-thumb" alt="" />
            <div class="title-meta">
              <span class="song-name">{{ song.name }}</span>
              <span class="song-artist">{{ song.artistText }}</span>
            </div>
          </div>
          <span class="col-album" :title="song.album.name">{{ song.album.name }}</span>
          <div class="col-actions" @click.stop>
            <button class="action-btn" @click="player.toggleLike(song)">
              <Heart
                :size="16"
                :fill="player.likedSongIds.value.has(song.id) ? 'var(--accent)' : 'none'"
                :color="player.likedSongIds.value.has(song.id) ? 'var(--accent)' : '#8b8b93'"
              />
            </button>
          </div>
          <span class="col-duration">{{ song.durationText }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Search, X, Play, Heart, Loader2 } from 'lucide-vue-next';
import { api } from '../services/api';
import { player } from '../stores/player';
import type { Song } from '../types/music';

const keyword = ref('');
const hotKeywords = ref<string[]>([]);
const results = ref<Song[]>([]);
const isLoading = ref(false);

onMounted(async () => {
  try {
    hotKeywords.value = await api.searchHot();
  } catch (e) {
    console.error('Failed to get hot search', e);
  }
});

async function handleSearch() {
  const kw = keyword.value.trim();
  if (!kw) return;
  isLoading.value = true;
  try {
    results.value = await api.search(kw, '1', 50);
  } catch (e) {
    console.error('Search failed', e);
  } finally {
    isLoading.value = false;
  }
}

function searchWord(word: string) {
  keyword.value = word;
  handleSearch();
}

function playAllResults() {
  if (results.value.length > 0) {
    player.play(results.value[0], results.value);
  }
}
</script>

<style scoped>
.view-container {
  padding: 32px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 28px;
}

.search-header {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.search-box {
  display: flex;
  align-items: center;
  gap: 12px;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 12px;
  padding: 10px 16px;
  max-width: 600px;
  backdrop-filter: blur(12px);
  transition: all 0.2s ease;
}

.search-box:focus-within {
  background: rgba(255, 255, 255, 0.12);
  border-color: var(--accent);
  box-shadow: 0 0 16px rgba(0, 113, 227, 0.35);
}

.search-icon {
  color: #8b8b93;
}

.search-input {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: #ffffff;
  font-size: 15px;
}

.search-input::placeholder {
  color: #71717a;
}

.clear-btn {
  background: transparent;
  border: none;
  color: #8b8b93;
  cursor: pointer;
  display: flex;
  align-items: center;
}

.hot-search-section {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.hot-title {
  font-size: 12px;
  color: #71717a;
}

.hot-tags {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.hot-pill {
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.04);
  border-radius: 14px;
  color: #a1a1aa;
  font-size: 12px;
  padding: 3px 10px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.hot-pill:hover {
  background: rgba(255, 255, 255, 0.12);
  color: #ffffff;
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

.results-container {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.results-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.results-count {
  font-size: 13px;
  color: #71717a;
}

.play-all-btn {
  background: var(--accent);
  border: none;
  border-radius: 16px;
  color: #ffffff;
  font-size: 12.5px;
  font-weight: 600;
  padding: 6px 14px;
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(0, 113, 227, 0.35);
}

/* Song Table */
.song-table {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.table-header {
  display: grid;
  grid-template-columns: 40px 1fr 240px 60px 70px;
  align-items: center;
  padding: 10px 14px;
  font-size: 12px;
  color: #71717a;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  font-weight: 600;
}

.table-row {
  display: grid;
  grid-template-columns: 40px 1fr 240px 60px 70px;
  align-items: center;
  padding: 8px 14px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.15s ease;
}

.table-row:hover {
  background: rgba(255, 255, 255, 0.06);
}

.table-row.active {
  background: rgba(255, 255, 255, 0.1);
}

.table-row.active .song-name {
  color: var(--accent);
  font-weight: 600;
}

.col-index {
  color: #71717a;
  font-size: 12px;
}

.song-title-cell {
  display: flex;
  align-items: center;
  gap: 12px;
  overflow: hidden;
}

.cell-thumb {
  width: 40px;
  height: 40px;
  border-radius: 6px;
  object-fit: cover;
  flex-shrink: 0;
}

.title-meta {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  gap: 2px;
}

.song-name {
  font-size: 13.5px;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.song-artist {
  font-size: 11.5px;
  color: #71717a;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.col-album {
  font-size: 12.5px;
  color: #a1a1aa;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.col-duration {
  font-size: 12px;
  color: #71717a;
}

.action-btn {
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 4px;
  display: flex;
  align-items: center;
}

.spin-icon {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
