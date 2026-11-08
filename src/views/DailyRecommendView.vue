<template>
  <div class="view-container">
    <!-- Header with Apple Music Calendar Card -->
    <div class="daily-header-card">
      <div class="calendar-widget">
        <span class="cal-weekday">{{ todayWeekday }}</span>
        <span class="cal-day">{{ todayDayNumber }}</span>
      </div>

      <div class="daily-meta">
        <span class="daily-tag">专属定制</span>
        <h1 class="view-title">每日推荐</h1>
        <p class="view-subtitle">根据你的音乐品味生成 · 每日 06:00 更新</p>

        <!-- Action Bar: Play & Shuffle (Apple Music Style) -->
        <div class="actions-row">
          <button class="primary-capsule-btn" @click="playAll(false)" :disabled="songs.length === 0">
            <Play :size="14" fill="#ffffff" />
            <span>播放全部 ({{ songs.length }})</span>
          </button>
          <button class="secondary-capsule-btn" @click="playAll(true)" :disabled="songs.length === 0">
            <Shuffle :size="14" />
            <span>随机播放</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>正在生成专属推荐...</span>
    </div>

    <!-- Songs Table -->
    <div v-else class="song-table">
      <div class="table-header">
        <span class="col-index">#</span>
        <span class="col-title">标题</span>
        <span class="col-artist">艺人</span>
        <span class="col-album">专辑</span>
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

        <!-- Title & Cover & Like -->
        <div class="col-title song-title-cell">
          <img :src="song.album.picUrl" class="cell-thumb" alt="" loading="lazy" />
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

        <!-- Album -->
        <div class="col-album">
          <span
            class="link-text"
            :title="song.album.name"
            @click.stop="song.album.id && player.navigate('album', song.album.id)"
          >
            {{ song.album.name }}
          </span>
        </div>

        <!-- Duration -->
        <div class="col-duration">
          <span>{{ song.durationText }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Play, Shuffle, Heart, Loader2, Clock } from 'lucide-vue-next';
import { api } from '../services/api';
import { player } from '../stores/player';
import type { Song } from '../types/music';

const songs = ref<Song[]>([]);
const isLoading = ref(true);

const todayDayNumber = new Date().getDate();
const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
const todayWeekday = weekdays[new Date().getDay()];

onMounted(async () => {
  try {
    const list = await api.getRecommendSongs();
    songs.value = list;
  } catch (e) {
    console.error('Daily load error', e);
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
  padding: 30px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 28px;
}

/* Calendar Card Header */
.daily-header-card {
  display: flex;
  align-items: center;
  gap: 28px;
  padding: 8px 0;
}

.calendar-widget {
  width: 100px;
  height: 100px;
  border-radius: 18px;
  background: linear-gradient(135deg, rgba(255, 255, 255, 0.12) 0%, rgba(255, 255, 255, 0.04) 100%);
  border: 1px solid rgba(255, 255, 255, 0.15);
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.cal-weekday {
  font-size: 11px;
  font-weight: 700;
  color: var(--accent);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.cal-day {
  font-size: 44px;
  font-weight: 800;
  color: #ffffff;
  line-height: 1;
  margin-top: 2px;
}

.daily-meta {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.daily-tag {
  font-size: 11px;
  font-weight: 700;
  color: var(--accent);
  text-transform: uppercase;
  letter-spacing: 0.8px;
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

.actions-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 10px;
}

.primary-capsule-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 18px;
  border-radius: 20px;
  background: var(--accent);
  border: none;
  color: #ffffff;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.15s ease, opacity 0.15s ease;
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

button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Loading */
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

/* Songs Table (Unified Apple Music Style) */
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
  flex: 2;
  min-width: 0;
  padding-right: 16px;
}

.song-title-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.cell-thumb {
  width: 36px;
  height: 36px;
  border-radius: 5px;
  object-fit: cover;
  flex-shrink: 0;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.3);
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
  flex: 1.2;
  min-width: 0;
  font-size: 12.5px;
  color: #a1a1aa;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  padding-right: 16px;
}

.col-album {
  flex: 1.2;
  min-width: 0;
  font-size: 12.5px;
  color: #71717a;
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