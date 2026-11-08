<template>
  <div class="view-container">
    <button class="back-btn" @click="player.navigate('home')">
      <ChevronLeft :size="18" />
      <span>返回</span>
    </button>

    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>正在加载歌单详情...</span>
    </div>

    <div v-else-if="playlist" class="playlist-detail-content">
      <!-- Header Meta Banner -->
      <div class="detail-header">
        <img :src="playlist.coverImgUrl" class="detail-cover" alt="" />
        <div class="header-info">
          <span class="playlist-tag">歌单</span>
          <h2 class="detail-title">{{ playlist.name }}</h2>
          <div class="creator-row" v-if="playlist.creator">
            <img :src="playlist.creator.avatarUrl" class="creator-avatar" alt="" />
            <span class="creator-name">{{ playlist.creator.nickname }}</span>
            <span class="meta-dot">·</span>
            <span class="tracks-count">{{ tracks.length }} 首歌曲</span>
          </div>
          <p class="detail-desc" v-if="playlist.description">{{ playlist.description }}</p>

          <div class="header-actions">
            <button class="primary-btn" @click="playAll">
              <Play :size="16" fill="#fff" />
              <span>播放全部</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Songs Table -->
      <div class="song-table">
        <div class="table-header">
          <span class="col-index">#</span>
          <span class="col-title">标题</span>
          <span class="col-album">专辑</span>
          <span class="col-actions">操作</span>
          <span class="col-duration">时长</span>
        </div>

        <div
          v-for="(song, idx) in tracks"
          :key="song.id"
          :class="['table-row', { active: player.currentSong.value?.id === song.id }]"
          @click="player.play(song, tracks)"
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
import { ChevronLeft, Play, Heart, Loader2 } from 'lucide-vue-next';
import { api } from '../services/api';
import { player } from '../stores/player';
import type { Playlist, Song } from '../types/music';

const playlist = ref<Playlist | null>(null);
const tracks = ref<Song[]>([]);
const isLoading = ref(true);

onMounted(async () => {
  const id = player.currentRouteParam.value;
  if (!id) return;
  isLoading.value = true;
  try {
    const res = await api.getPlaylistDetail(id);
    playlist.value = res.playlist;
    tracks.value = res.tracks;
  } catch (e) {
    console.error('Playlist detail error', e);
  } finally {
    isLoading.value = false;
  }
});

function playAll() {
  if (tracks.value.length > 0) {
    player.play(tracks.value[0], tracks.value);
  }
}
</script>

<style scoped>
.view-container {
  padding: 32px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.back-btn {
  background: transparent;
  border: none;
  color: #a1a1aa;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 13.5px;
  cursor: pointer;
  align-self: flex-start;
  transition: color 0.15s ease;
}

.back-btn:hover {
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

.playlist-detail-content {
  display: flex;
  flex-direction: column;
  gap: 32px;
}

.detail-header {
  display: flex;
  gap: 28px;
  align-items: flex-start;
}

.detail-cover {
  width: 200px;
  height: 200px;
  border-radius: 16px;
  object-fit: cover;
  box-shadow: 0 16px 36px rgba(0, 0, 0, 0.5);
  flex-shrink: 0;
}

.header-info {
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex: 1;
}

.playlist-tag {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  color: var(--accent);
  letter-spacing: 0.5px;
}

.detail-title {
  margin: 0;
  font-size: 26px;
  font-weight: 800;
  color: #ffffff;
  line-height: 1.3;
}

.creator-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12.5px;
  color: #a1a1aa;
}

.creator-avatar {
  width: 24px;
  height: 24px;
  border-radius: 50%;
}

.creator-name {
  color: #ffffff;
  font-weight: 500;
}

.meta-dot {
  color: #52525b;
}

.detail-desc {
  margin: 0;
  font-size: 13px;
  color: #71717a;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.header-actions {
  margin-top: 6px;
}

.primary-btn {
  background: var(--accent);
  border: none;
  border-radius: 20px;
  color: #ffffff;
  font-size: 13.5px;
  font-weight: 600;
  padding: 8px 20px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  box-shadow: 0 4px 16px rgba(0, 113, 227, 0.4);
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
