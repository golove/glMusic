<template>
  <div class="view-container">
    <!-- Top Pinned Return Button -->
    <div class="top-nav-bar">
      <button class="nav-back-circle-btn" @click="player.goBack()" title="返回 (Alt + ←)">
        <ChevronLeft :size="18" />
      </button>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>正在加载专辑详情...</span>
    </div>

    <div v-else-if="album" class="album-detail-content">
      <!-- Header Meta Banner -->
      <div class="detail-header">
        <img :src="album.picUrl" class="detail-cover" alt="" />
        <div class="header-info">
          <span class="album-tag">精选专辑</span>
          <h1 class="detail-title">{{ album.name }}</h1>

          <div class="artist-row" v-if="album.artist">
            <span
              class="artist-name link-text"
              @click="album.artist?.id && player.navigate('artist', album.artist.id)"
            >
              {{ album.artist.name }}
            </span>
            <span class="meta-dot">·</span>
            <span class="tracks-count">{{ songs.length }} 首歌曲</span>
            <span class="meta-dot" v-if="publishDate">·</span>
            <span class="publish-date" v-if="publishDate">{{ publishDate }} 发行</span>
          </div>

          <!-- Playback Action Bar -->
          <div class="header-actions">
            <button class="primary-capsule-btn" @click="playAll(false)" :disabled="songs.length === 0">
              <Play :size="14" fill="#ffffff" />
              <span>播放全部</span>
            </button>
            <button class="secondary-capsule-btn" @click="playAll(true)" :disabled="songs.length === 0">
              <Shuffle :size="14" />
              <span>随机播放</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Songs Table -->
      <div class="song-table">
        <div class="table-header">
          <span class="col-index">#</span>
          <span class="col-title">标题</span>
          <span class="col-artist">艺人</span>
          <span class="col-duration">
            <Clock :size="13" />
          </span>
        </div>

        <div
          v-for="(song, idx) in songs"
          :key="song.id"
          :class="['table-row', { active: player.currentSong.value?.id === song.id }]"
          @click="player.play(song, songs)"
        >
          <!-- Index or Playing Equalizer -->
          <div class="col-index">
            <span v-if="player.currentSong.value?.id === song.id && player.isPlaying.value" class="equalizer-bars">
              <span class="bar bar-1"></span>
              <span class="bar bar-2"></span>
              <span class="bar bar-3"></span>
            </span>
            <Play v-else class="row-play-hint" :size="12" fill="currentColor" />
            <span class="row-num">{{ idx + 1 }}</span>
          </div>

          <!-- Title & Like -->
          <div class="col-title song-title-cell">
            <div class="title-meta">
              <span class="song-name" :title="song.name">{{ song.name }}</span>
              <button
                class="inline-like-btn"
                :class="{ active: player.likedSongIds.value.has(song.id) }"
                @click.stop="player.toggleLike(song)"
                title="喜欢"
              >
                <Heart :size="13" :fill="player.likedSongIds.value.has(song.id) ? 'var(--accent)' : 'none'" />
              </button>
            </div>
          </div>

          <!-- Artist -->
          <div class="col-artist">
            <span
              class="link-text"
              :title="song.artistText"
              @click.stop="song.artists[0]?.id && player.navigate('artist', song.artists[0].id)"
            >
              {{ song.artistText }}
            </span>
          </div>

          <!-- Duration -->
          <div class="col-duration">
            <span>{{ song.durationText }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { ChevronLeft, Play, Shuffle, Heart, Loader2, Clock } from 'lucide-vue-next';
import { api } from '../services/api';
import { player } from '../stores/player';
import type { Album, Song } from '../types/music';

const album = ref<Album | null>(null);
const songs = ref<Song[]>([]);
const isLoading = ref(true);

const publishDate = computed(() => {
  if (!album.value?.publishTime) return '';
  const d = new Date(album.value.publishTime);
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
});

onMounted(async () => {
  const id = player.currentRouteParam.value;
  if (!id) return;
  isLoading.value = true;
  try {
    const res = await api.getAlbum(id);
    album.value = res.album;
    songs.value = res.songs;
  } catch (e) {
    console.error('Album detail error', e);
  } finally {
    isLoading.value = false;
  }
});

function playAll(shuffled = false) {
  if (songs.value.length === 0) return;
  const list = shuffled ? [...songs.value].sort(() => Math.random() - 0.5) : songs.value;
  player.play(list[0], list);
}
</script>

<style scoped>
.view-container {
  padding: 24px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.top-nav-bar {
  display: flex;
  align-items: center;
}

.nav-back-circle-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: color-mix(in srgb, var(--accent) 15%, rgba(255, 255, 255, 0.08));
  color: var(--accent);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.16s ease;
}

.nav-back-circle-btn:hover {
  transform: scale(1.08);
  background: color-mix(in srgb, var(--accent) 25%, rgba(255, 255, 255, 0.12));
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

.spin-icon {
  animation: spin 1s linear infinite;
  color: var(--accent);
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.album-detail-content {
  display: flex;
  flex-direction: column;
  gap: 32px;
}

.detail-header {
  display: flex;
  gap: 28px;
  align-items: flex-end;
}

.detail-cover {
  width: 200px;
  height: 200px;
  border-radius: 12px;
  object-fit: cover;
  box-shadow: 0 16px 36px rgba(0, 0, 0, 0.5), 0 0 30px color-mix(in srgb, var(--accent) 20%, transparent);
  flex-shrink: 0;
}

.header-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
}

.album-tag {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.8px;
  color: var(--accent);
}

.detail-title {
  margin: 0;
  font-size: 28px;
  font-weight: 800;
  color: #ffffff;
  letter-spacing: -0.4px;
  line-height: 1.25;
}

.artist-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #a1a1aa;
}

.artist-name {
  color: #ffffff;
  font-weight: 600;
}

.meta-dot {
  color: #52525b;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 8px;
}

.primary-capsule-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 20px;
  border-radius: 20px;
  background: var(--accent);
  border: none;
  color: #ffffff;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.15s ease;
  box-shadow: 0 4px 14px color-mix(in srgb, var(--accent) 35%, transparent);
}

.primary-capsule-btn:hover:not(:disabled) {
  transform: scale(1.03);
}

.secondary-capsule-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 18px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.1);
  border: none;
  color: #ffffff;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.15s ease;
}

.secondary-capsule-btn:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.16);
  transform: scale(1.03);
}

/* Song Table */
.song-table {
  display: flex;
  flex-direction: column;
  width: 100%;
}

.table-header {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  font-size: 11.5px;
  font-weight: 600;
  color: #71717a;
  user-select: none;
}

.table-row {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.15s ease;
  user-select: none;
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
  width: 38px;
  text-align: center;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #71717a;
  font-size: 12px;
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
}

.row-play-hint {
  display: none;
  color: #ffffff;
}

.table-row:hover .row-num {
  display: none;
}

.table-row:hover .row-play-hint {
  display: block;
}

.equalizer-bars {
  display: flex;
  align-items: flex-end;
  gap: 2px;
  height: 12px;
}

.bar {
  width: 2px;
  background: var(--accent);
  border-radius: 1px;
  animation: eqJump 0.8s ease-in-out infinite alternate;
}

.bar-1 { height: 8px; animation-delay: 0.1s; }
.bar-2 { height: 12px; animation-delay: 0.3s; }
.bar-3 { height: 6px; animation-delay: 0.2s; }

@keyframes eqJump {
  from { height: 3px; }
  to { height: 12px; }
}

.col-title {
  flex: 2.5;
  min-width: 0;
  padding-right: 16px;
}

.song-title-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.title-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  overflow: hidden;
}

.song-name {
  font-size: 13px;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.inline-like-btn {
  background: transparent;
  border: none;
  color: #71717a;
  cursor: pointer;
  padding: 2px;
  display: flex;
  align-items: center;
  opacity: 0;
  transition: opacity 0.15s ease, transform 0.15s ease;
}

.table-row:hover .inline-like-btn,
.inline-like-btn.active {
  opacity: 1;
}

.inline-like-btn:hover {
  transform: scale(1.15);
  color: #ffffff;
}

.inline-like-btn.active {
  color: var(--accent);
}

.col-artist {
  flex: 1.5;
  min-width: 0;
  font-size: 12.5px;
  color: #a1a1aa;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  padding-right: 16px;
}

.col-duration {
  width: 60px;
  text-align: right;
  font-size: 12px;
  font-variant-numeric: tabular-nums;
  color: #71717a;
  flex-shrink: 0;
}

.link-text:hover {
  color: #ffffff;
  text-decoration: underline;
  cursor: pointer;
}
</style>