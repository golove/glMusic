<template>
  <div class="view-container">
    <button class="back-btn" @click="player.goBack()">
      <ChevronLeft :size="18" />
      <span>返回</span>
    </button>

    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>正在加载歌手信息...</span>
    </div>

    <div v-else-if="artist" class="artist-detail-content">
      <!-- Header Banner -->
      <div class="detail-header">
        <img :src="artist.picUrl" class="detail-avatar" alt="" />
        <div class="header-info">
          <span class="artist-tag">歌手</span>
          <h2 class="detail-title">{{ artist.name }}</h2>
          <div class="meta-row">
            <span v-if="artist.musicSize">单曲数: {{ artist.musicSize }}</span>
            <span class="meta-dot" v-if="artist.musicSize && artist.albumSize">·</span>
            <span v-if="artist.albumSize">专辑数: {{ artist.albumSize }}</span>
          </div>

          <div class="header-actions">
            <button class="primary-btn" @click="playAll">
              <Play :size="16" fill="#fff" />
              <span>播放热门单曲</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Section Tabs: 热门歌曲 / 所有专辑 -->
      <div class="tabs-header">
        <button
          :class="['tab-btn', { active: currentTab === 'songs' }]"
          @click="currentTab = 'songs'"
        >
          热门单曲 ({{ hotSongs.length }})
        </button>
        <button
          :class="['tab-btn', { active: currentTab === 'albums' }]"
          @click="currentTab = 'albums'"
        >
          热门专辑 ({{ albums.length }})
        </button>
      </div>

      <!-- Tab: Songs -->
      <div v-if="currentTab === 'songs'" class="song-table">
        <div class="table-header">
          <span class="col-index">#</span>
          <span class="col-title">标题</span>
          <span class="col-album">专辑</span>
          <span class="col-actions">操作</span>
          <span class="col-duration">时长</span>
        </div>

        <div
          v-for="(song, idx) in hotSongs"
          :key="song.id"
          :class="['table-row', { active: player.currentSong.value?.id === song.id }]"
          @click="player.play(song, hotSongs)"
        >
          <span class="col-index">{{ idx + 1 }}</span>
          <div class="col-title song-title-cell">
            <img :src="song.album.picUrl" class="cell-thumb" alt="" />
            <div class="title-meta">
              <span class="song-name">{{ song.name }}</span>
            </div>
          </div>
          <span class="col-album" :title="song.album.name" @click.stop="player.navigate('album', song.album.id)">
            {{ song.album.name }}
          </span>
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

      <!-- Tab: Albums -->
      <div v-else class="albums-grid">
        <div
          v-for="alb in albums"
          :key="alb.id"
          class="album-card"
          @click="player.navigate('album', alb.id)"
        >
          <div class="album-cover-box">
            <img :src="alb.picUrl" class="album-cover-img" alt="" />
            <div class="play-overlay">
              <Play :size="22" fill="#fff" />
            </div>
          </div>
          <span class="album-card-title" :title="alb.name">{{ alb.name }}</span>
          <span class="album-card-size">{{ alb.size ? `${alb.size} 首歌曲` : '专辑' }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import { ChevronLeft, Play, Heart, Loader2 } from 'lucide-vue-next';
import { api } from '../services/api';
import { player } from '../stores/player';
import type { Artist, Song, Album } from '../types/music';

const artist = ref<Artist | null>(null);
const hotSongs = ref<Song[]>([]);
const albums = ref<Album[]>([]);
const currentTab = ref<'songs' | 'albums'>('songs');
const isLoading = ref(true);

async function loadArtist() {
  const id = player.currentRouteParam.value;
  if (!id) return;
  isLoading.value = true;
  try {
    const [detailRes, albRes] = await Promise.all([
      api.getArtistDetail(id),
      api.getArtistAlbums(id, 30)
    ]);
    artist.value = detailRes.artist;
    hotSongs.value = detailRes.hotSongs;
    albums.value = albRes;
  } catch (e) {
    console.error('Artist detail error', e);
  } finally {
    isLoading.value = false;
  }
}

onMounted(() => {
  loadArtist();
});

watch(() => player.currentRouteParam.value, () => {
  if (player.currentRoute.value === 'artist') {
    loadArtist();
  }
});

function playAll() {
  if (hotSongs.value.length > 0) {
    player.play(hotSongs.value[0], hotSongs.value);
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

.artist-detail-content {
  display: flex;
  flex-direction: column;
  gap: 28px;
}

.detail-header {
  display: flex;
  gap: 28px;
  align-items: center;
}

.detail-avatar {
  width: 160px;
  height: 160px;
  border-radius: 50%;
  object-fit: cover;
  box-shadow: 0 16px 36px rgba(0, 0, 0, 0.5);
  border: 2px solid rgba(255, 255, 255, 0.1);
  flex-shrink: 0;
}

.header-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
}

.artist-tag {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  color: var(--accent);
  letter-spacing: 0.5px;
}

.detail-title {
  margin: 0;
  font-size: 32px;
  font-weight: 800;
  color: #ffffff;
  line-height: 1.2;
}

.meta-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #a1a1aa;
}

.meta-dot {
  color: #52525b;
}

.header-actions {
  margin-top: 8px;
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

.tabs-header {
  display: flex;
  gap: 16px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  padding-bottom: 8px;
}

.tab-btn {
  background: transparent;
  border: none;
  font-size: 15px;
  font-weight: 600;
  color: #71717a;
  cursor: pointer;
  padding: 6px 4px;
  position: relative;
  transition: color 0.15s ease;
}

.tab-btn:hover {
  color: #ffffff;
}

.tab-btn.active {
  color: var(--accent);
}

.tab-btn.active::after {
  content: '';
  position: absolute;
  bottom: -9px;
  left: 0;
  right: 0;
  height: 2px;
  background: var(--accent);
  border-radius: 2px;
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
}

.song-name {
  font-size: 13.5px;
  color: #ffffff;
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

.col-album:hover {
  color: #ffffff;
  text-decoration: underline;
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

/* Albums Grid */
.albums-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 20px;
}

.album-card {
  display: flex;
  flex-direction: column;
  gap: 6px;
  cursor: pointer;
}

.album-cover-box {
  position: relative;
  width: 100%;
  aspect-ratio: 1;
  border-radius: 10px;
  overflow: hidden;
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.35);
}

.album-cover-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.2s ease;
}

.album-card:hover .album-cover-img {
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

.album-card:hover .play-overlay {
  opacity: 1;
}

.album-card-title {
  font-size: 13.5px;
  font-weight: 600;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.album-card-size {
  font-size: 11.5px;
  color: #71717a;
}

.spin-icon {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
