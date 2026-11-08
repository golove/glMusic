<template>
  <div class="player-bar-capsule" :style="{ '--accent': player.accentColor.value }">
    <!-- Left: Song Info -->
    <div class="left-section">
      <div class="artwork-wrapper" @click="player.isShowingLyrics.value = !player.isShowingLyrics.value">
        <img
          :src="player.currentSong.value?.album.picUrl || 'https://p1.music.126.net/6y-UleORITEDbvrOLj0QGg==/109951163077757723.jpg'"
          class="artwork-img"
          alt="Cover"
        />
        <div class="artwork-overlay">
          <Maximize2 :size="14" color="#fff" />
        </div>
      </div>
      <div class="meta-wrapper">
        <div
          class="song-title clickable"
          :title="player.currentSong.value?.name"
          @click="player.currentSong.value?.album.id && player.navigate('album', player.currentSong.value.album.id)"
        >
          {{ player.currentSong.value?.name || '等待播放' }}
        </div>
        <div
          class="song-artist clickable"
          :title="player.currentSong.value?.artistText"
          @click="player.currentSong.value?.artists[0]?.id && player.navigate('artist', player.currentSong.value.artists[0].id)"
        >
          {{ player.currentSong.value?.artistText || 'glMusic' }}
        </div>
      </div>
      <!-- Like button -->
      <button
        v-if="player.currentSong.value"
        class="icon-btn like-btn"
        :class="{ active: player.likedSongIds.value.has(player.currentSong.value.id) }"
        @click="player.toggleLike(player.currentSong.value)"
      >
        <Heart :size="16" :fill="player.likedSongIds.value.has(player.currentSong.value.id) ? 'var(--accent)' : 'none'" />
      </button>
    </div>

    <!-- Center: Playback Controls & Progress Bar -->
    <div class="center-section">
      <div class="controls-row">
        <!-- Shuffle -->
        <button
          class="icon-btn small-btn"
          :class="{ active: player.isShuffled.value }"
          @click="player.toggleShuffle()"
          title="随机播放"
        >
          <Shuffle :size="15" />
        </button>

        <!-- Prev -->
        <button class="icon-btn" @click="player.previous()" title="上一首">
          <SkipBack :size="18" />
        </button>

        <!-- Play / Pause -->
        <button class="play-btn" @click="player.togglePlay()" title="播放/暂停">
          <Loader2 v-if="player.isLoading.value" class="spin-icon" :size="20" />
          <Pause v-else-if="player.isPlaying.value" :size="20" />
          <Play v-else :size="20" style="margin-left: 2px;" />
        </button>

        <!-- Next -->
        <button class="icon-btn" @click="player.next()" title="下一首">
          <SkipForward :size="18" />
        </button>

        <!-- Repeat Mode -->
        <button
          class="icon-btn small-btn"
          :class="{ active: player.repeatMode.value !== 'off' }"
          @click="player.toggleRepeatMode()"
          title="循环模式"
        >
          <Repeat1 v-if="player.repeatMode.value === 'one'" :size="15" />
          <Repeat v-else :size="15" />
        </button>
      </div>

      <!-- Time slider -->
      <div class="progress-row">
        <span class="time-label">{{ formatTime(player.currentTime.value) }}</span>
        <div class="slider-track" @click="onSliderClick">
          <div
            class="slider-fill"
            :style="{ width: `${player.duration.value ? (player.currentTime.value / player.duration.value) * 100 : 0}%` }"
          ></div>
        </div>
        <span class="time-label">{{ formatTime(player.duration.value) }}</span>
      </div>
    </div>

    <!-- Right: Quality, Volume, Lyrics & Queue -->
    <div class="right-section">
      <!-- Quality Selector -->
      <div class="quality-dropdown">
        <button class="quality-badge" @click="toggleQualityMenu">
          {{ qualityLabels[player.soundQuality.value] }}
        </button>
        <div v-if="showQualityMenu" class="quality-menu">
          <button
            v-for="(label, key) in qualityLabels"
            :key="key"
            :class="['quality-item', { active: player.soundQuality.value === key }]"
            @click="selectQuality(key as any)"
          >
            {{ label }}
          </button>
        </div>
      </div>

      <!-- Volume -->
      <div class="volume-container">
        <button class="icon-btn small-btn" @click="player.toggleMute()">
          <VolumeX v-if="player.isMuted.value || player.volume.value === 0" :size="16" />
          <Volume1 v-else-if="player.volume.value < 0.5" :size="16" />
          <Volume2 v-else :size="16" />
        </button>
        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          :value="player.volume.value"
          @input="onVolumeChange"
          class="volume-slider"
        />
      </div>

      <!-- Lyrics Toggle -->
      <button
        class="icon-btn"
        :class="{ active: player.isShowingLyrics.value }"
        @click="player.isShowingLyrics.value = !player.isShowingLyrics.value"
        title="歌词"
      >
        <Mic2 :size="17" />
      </button>

      <!-- Queue Drawer Toggle -->
      <button
        class="icon-btn"
        :class="{ active: player.isShowingQueue.value }"
        @click="player.isShowingQueue.value = !player.isShowingQueue.value"
        title="播放列表"
      >
        <ListMusic :size="17" />
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import {
  Play,
  Pause,
  SkipBack,
  SkipForward,
  Shuffle,
  Repeat,
  Repeat1,
  Volume1,
  Volume2,
  VolumeX,
  Mic2,
  ListMusic,
  Heart,
  Loader2,
  Maximize2
} from 'lucide-vue-next';
import { player } from '../stores/player';
import type { SoundQuality } from '../types/music';

const showQualityMenu = ref(false);

const qualityLabels: Record<SoundQuality, string> = {
  standard: '标准',
  exhigh: '极高',
  lossless: '无损',
  hires: 'Hi-Res'
};

function toggleQualityMenu() {
  showQualityMenu.value = !showQualityMenu.value;
}

function selectQuality(q: SoundQuality) {
  player.setQuality(q);
  showQualityMenu.value = false;
}

function onVolumeChange(e: Event) {
  const target = e.target as HTMLInputElement;
  player.setVolume(parseFloat(target.value));
}

function onSliderClick(e: MouseEvent) {
  const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
  const clickX = e.clientX - rect.left;
  const ratio = Math.max(0, Math.min(1, clickX / rect.width));
  player.seekByProgress(ratio);
}

function formatTime(seconds: number): string {
  if (isNaN(seconds) || seconds < 0) return '0:00';
  const min = Math.floor(seconds / 60);
  const sec = Math.floor(seconds % 60);
  return `${min}:${sec < 10 ? '0' : ''}${sec}`;
}
</script>

<style scoped>
.player-bar-capsule {
  height: 64px;
  background: rgba(30, 32, 38, 0.78);
  backdrop-filter: blur(35px) saturate(210%);
  -webkit-backdrop-filter: blur(35px) saturate(210%);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 32px;
  box-shadow: 0 16px 36px rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  user-select: none;
  position: relative;
  z-index: 100;
}

/* Left Section */
.left-section {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 250px;
}

.artwork-wrapper {
  position: relative;
  width: 44px;
  height: 44px;
  border-radius: 8px;
  overflow: hidden;
  cursor: pointer;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.35);
  flex-shrink: 0;
}

.artwork-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.25s ease;
}

.artwork-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: opacity 0.2s ease;
}

.artwork-wrapper:hover .artwork-overlay {
  opacity: 1;
}

.artwork-wrapper:hover .artwork-img {
  transform: scale(1.08);
}

.meta-wrapper {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  gap: 2px;
}

.song-title {
  font-size: 13.5px;
  font-weight: 600;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.clickable {
  cursor: pointer;
  transition: color 0.15s ease;
}

.clickable:hover {
  color: var(--accent);
  text-decoration: underline;
}

.song-artist {
  font-size: 11.5px;
  color: #94949b;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Center Section */
.center-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  flex: 1;
  max-width: 480px;
}

.controls-row {
  display: flex;
  align-items: center;
  gap: 16px;
}

.play-btn {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: none;
  background: #ffffff;
  color: #121316;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: transform 0.15s ease, background 0.15s ease;
}

.play-btn:hover {
  transform: scale(1.08);
  background: #f0f0f5;
}

.play-btn:active {
  transform: scale(0.96);
}

.progress-row {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
}

.time-label {
  font-size: 10.5px;
  color: #83838a;
  min-width: 32px;
  text-align: center;
}

.slider-track {
  flex: 1;
  height: 4px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 2px;
  cursor: pointer;
  position: relative;
  overflow: hidden;
  transition: height 0.15s ease;
}

.slider-track:hover {
  height: 6px;
}

.slider-fill {
  height: 100%;
  background: var(--accent);
  border-radius: 2px;
  transition: width 0.1s linear;
}

/* Right Section */
.right-section {
  display: flex;
  align-items: center;
  gap: 14px;
  width: 250px;
  justify-content: flex-end;
}

.quality-dropdown {
  position: relative;
}

.quality-badge {
  font-size: 11px;
  font-weight: 600;
  padding: 3px 8px;
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.18);
  color: #e4e4e7;
  cursor: pointer;
  transition: all 0.15s ease;
}

.quality-badge:hover {
  background: rgba(255, 255, 255, 0.18);
  border-color: rgba(255, 255, 255, 0.3);
}

.quality-menu {
  position: absolute;
  bottom: calc(100% + 10px);
  right: 0;
  background: rgba(30, 32, 38, 0.95);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 8px;
  padding: 4px;
  display: flex;
  flex-direction: column;
  gap: 2px;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.4);
}

.quality-item {
  border: none;
  background: transparent;
  color: #a1a1aa;
  padding: 6px 14px;
  font-size: 12px;
  cursor: pointer;
  border-radius: 5px;
  white-space: nowrap;
  text-align: left;
}

.quality-item:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
}

.quality-item.active {
  color: var(--accent);
  font-weight: 600;
}

.volume-container {
  display: flex;
  align-items: center;
  gap: 6px;
}

.volume-slider {
  width: 65px;
  height: 4px;
  appearance: none;
  background: rgba(255, 255, 255, 0.18);
  border-radius: 2px;
  cursor: pointer;
  outline: none;
}

.volume-slider::-webkit-slider-thumb {
  appearance: none;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #ffffff;
  cursor: pointer;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
}

/* Common Buttons */
.icon-btn {
  background: transparent;
  border: none;
  color: #8b8b93;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  padding: 6px;
  border-radius: 6px;
  transition: all 0.15s ease;
}

.icon-btn:hover {
  color: #ffffff;
  background: rgba(255, 255, 255, 0.08);
}

.icon-btn.active {
  color: var(--accent);
}

.small-btn {
  padding: 4px;
}

.like-btn.active {
  color: var(--accent);
}

.spin-icon {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
