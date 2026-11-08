<template>
  <div class="player-bar-capsule" :style="{ '--accent': player.accentColor.value }">
    <!-- Left Section: Playback Controls (Matching Mac glMusic PlayerBar) -->
    <div class="playback-controls-section">
      <!-- Shuffle -->
      <button
        class="icon-btn small-btn"
        :class="{ active: player.isShuffled.value }"
        @click="player.toggleShuffle()"
        title="随机播放"
      >
        <Shuffle :size="13" />
      </button>

      <!-- Previous -->
      <button class="icon-btn" @click="player.previous()" title="上一首">
        <SkipBack :size="16" />
      </button>

      <!-- Play / Pause -->
      <button class="main-play-btn" @click="player.togglePlay()" title="播放/暂停">
        <Loader2 v-if="player.isLoading.value" class="spin-icon" :size="20" />
        <Pause v-else-if="player.isPlaying.value" :size="20" />
        <Play v-else :size="20" style="margin-left: 2px;" />
      </button>

      <!-- Next -->
      <button class="icon-btn" @click="player.next()" title="下一首">
        <SkipForward :size="16" />
      </button>

      <!-- Repeat Mode -->
      <button
        class="icon-btn small-btn"
        :class="{ active: player.repeatMode.value !== 'off' }"
        @click="player.toggleRepeatMode()"
        :title="player.repeatMode.value === 'one' ? '单曲循环' : (player.repeatMode.value === 'all' ? '列表循环' : '顺序播放')"
      >
        <Repeat1 v-if="player.repeatMode.value === 'one'" :size="13" />
        <Repeat v-else :size="13" />
      </button>
    </div>

    <!-- Center Section: Song Metadata, Badges & Interactive Progress Slider -->
    <div class="center-track-section">
      <!-- Top Row: Cover Artwork, Title, Artist, Sound Quality Badge, Like Button -->
      <div class="track-header-row">
        <!-- Cover Art (Click to toggle Lyrics) -->
        <div class="artwork-wrapper" @click="player.isShowingLyrics.value = !player.isShowingLyrics.value" title="点击展开全屏歌词">
          <img
            :src="player.currentSong.value?.album.picUrl || 'https://p1.music.126.net/6y-UleORITEDbvrOLj0QGg==/109951163077757723.jpg'"
            class="artwork-img"
            alt="Cover"
          />
          <div class="artwork-overlay">
            <Maximize2 :size="13" color="#fff" />
          </div>
        </div>

        <!-- Meta Text -->
        <div class="meta-wrapper">
          <div
            class="song-title clickable"
            :title="player.currentSong.value?.name"
            @click="player.currentSong.value?.album.id && player.navigate('album', player.currentSong.value.album.id)"
          >
            {{ player.currentSong.value?.name || '未在播放' }}
          </div>
          <div
            class="song-artist clickable"
            :title="player.currentSong.value?.artistText"
            @click="player.currentSong.value?.artists[0]?.id && player.navigate('artist', player.currentSong.value.artists[0].id)"
          >
            {{ player.currentSong.value?.artistText || 'glMusic' }}
          </div>
        </div>

        <!-- Sound Quality Badge (Apple Music style) -->
        <div class="quality-badge-container">
          <button class="quality-badge-btn" @click="toggleQualityMenu" :title="`音质选择：当前为 ${qualityLabels[player.soundQuality.value]}`">
            {{ qualityLabels[player.soundQuality.value] }}
          </button>

          <!-- Quality Dropdown Menu -->
          <div v-if="showQualityMenu" class="quality-menu" @click="showQualityMenu = false">
            <button
              v-for="(label, key) in qualityLabels"
              :key="key"
              :class="['quality-item', { active: player.soundQuality.value === key }]"
              @click="selectQuality(key as SoundQuality)"
            >
              <span>{{ label }}</span>
              <span v-if="player.soundQuality.value === key" class="check">✓</span>
            </button>
          </div>
        </div>

        <!-- Like Button -->
        <button
          v-if="player.currentSong.value"
          class="like-btn"
          :class="{ active: player.likedSongIds.value.has(player.currentSong.value.id) }"
          @click="player.toggleLike(player.currentSong.value)"
          :title="player.likedSongIds.value.has(player.currentSong.value.id) ? '取消喜欢' : '喜欢这首歌'"
        >
          <Heart :size="15" :fill="player.likedSongIds.value.has(player.currentSong.value.id) ? 'var(--accent)' : 'none'" />
        </button>
      </div>

      <!-- Bottom Row: Time Scrubber Slider -->
      <div class="progress-bar-row">
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

    <!-- Right Section: Queue Drawer & Volume Scrubbing -->
    <div class="extras-section">
      <!-- Synced Lyrics Toggle -->
      <button
        class="icon-btn"
        :class="{ active: player.isShowingLyrics.value }"
        @click="player.isShowingLyrics.value = !player.isShowingLyrics.value"
        title="歌词"
      >
        <Mic2 :size="16" />
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

      <!-- Volume -->
      <div class="volume-container">
        <button class="icon-btn vol-btn" @click="toggleMute" title="静音/取消静音">
          <VolumeX v-if="player.volume.value === 0 || player.isMuted.value" :size="16" />
          <Volume1 v-else-if="player.volume.value < 0.5" :size="16" />
          <Volume2 v-else :size="16" />
        </button>
        <div class="volume-slider-wrapper">
          <input
            type="range"
            min="0"
            max="1"
            step="0.01"
            :value="player.isMuted.value ? 0 : player.volume.value"
            class="volume-slider"
            @input="onVolumeChange"
          />
        </div>
      </div>
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

let lastVolume = 0.7;
function toggleMute() {
  if (player.volume.value > 0) {
    lastVolume = player.volume.value;
    player.setVolume(0);
  } else {
    player.setVolume(lastVolume > 0 ? lastVolume : 0.7);
  }
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
  height: 52px;
  background: rgba(28, 30, 36, 0.86);
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 26px;
  box-shadow: 0 16px 36px rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  user-select: none;
  position: relative;
  z-index: 100;
  contain: layout style;
}

/* Left Section: Playback Controls (155px width like Mac) */
.playback-controls-section {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 155px;
  flex-shrink: 0;
}

.icon-btn {
  background: transparent;
  border: none;
  color: #a1a1aa;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.16s ease;
}

.icon-btn:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
}

.icon-btn.small-btn {
  width: 24px;
  height: 24px;
}

.icon-btn.active {
  color: var(--accent, #f43f5e);
}

.main-play-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: #ffffff;
  color: #000000;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.16s ease;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
}

.main-play-btn:hover {
  transform: scale(1.06);
  background: #f4f4f5;
}

.spin-icon {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* Center Section: Track Info & Scrubber */
.center-track-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  padding: 0 16px;
  min-width: 0;
}

.track-header-row {
  display: flex;
  align-items: center;
  gap: 10px;
  max-width: 100%;
}

.artwork-wrapper {
  position: relative;
  width: 30px;
  height: 30px;
  border-radius: 5px;
  overflow: hidden;
  cursor: pointer;
  flex-shrink: 0;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.35);
}

.artwork-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.artwork-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: opacity 0.16s ease;
}

.artwork-wrapper:hover .artwork-overlay {
  opacity: 1;
}

.meta-wrapper {
  display: flex;
  align-items: baseline;
  gap: 6px;
  min-width: 0;
  max-width: 320px;
}

.song-title {
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.song-artist {
  font-size: 11px;
  color: #a1a1aa;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.clickable {
  cursor: pointer;
}

.clickable:hover {
  text-decoration: underline;
  color: #ffffff;
}

/* Sound Quality Badge (Mac HIG style) */
.quality-badge-container {
  position: relative;
}

.quality-badge-btn {
  font-size: 10px;
  font-weight: 600;
  color: var(--accent, #f43f5e);
  background: color-mix(in srgb, var(--accent) 12%, transparent);
  border: 0.8px solid color-mix(in srgb, var(--accent) 70%, transparent);
  border-radius: 4px;
  padding: 1px 5px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.quality-badge-btn:hover {
  background: color-mix(in srgb, var(--accent) 22%, transparent);
}

.quality-menu {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 50%;
  transform: translateX(-50%);
  background: rgba(28, 30, 36, 0.96);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 8px;
  padding: 4px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.45);
  display: flex;
  flex-direction: column;
  min-width: 90px;
  z-index: 120;
}

.quality-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 5px 8px;
  border-radius: 5px;
  border: none;
  background: transparent;
  color: #d4d4d8;
  font-size: 11.5px;
  cursor: pointer;
  transition: background 0.15s ease;
}

.quality-item:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #ffffff;
}

.quality-item.active {
  color: var(--accent, #f43f5e);
  font-weight: 600;
}

.like-btn {
  background: transparent;
  border: none;
  color: #71717a;
  cursor: pointer;
  padding: 2px;
  display: flex;
  align-items: center;
  transition: transform 0.15s ease, color 0.15s ease;
}

.like-btn:hover {
  transform: scale(1.15);
  color: #ffffff;
}

.like-btn.active {
  color: var(--accent, #f43f5e);
}

/* Progress Bar Row */
.progress-bar-row {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  max-width: 480px;
}

.time-label {
  font-size: 10px;
  font-variant-numeric: tabular-nums;
  color: #71717a;
  min-width: 28px;
  text-align: center;
}

.slider-track {
  flex: 1;
  height: 3px;
  background: rgba(255, 255, 255, 0.16);
  border-radius: 2px;
  position: relative;
  cursor: pointer;
  transition: height 0.15s ease;
}

.slider-track:hover {
  height: 5px;
}

.slider-fill {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background: #ffffff;
  border-radius: 2px;
  pointer-events: none;
}

/* Right Section: Extras (~175px like Mac) */
.extras-section {
  display: flex;
  align-items: center;
  gap: 6px;
  width: 175px;
  justify-content: flex-end;
  flex-shrink: 0;
}

.volume-container {
  display: flex;
  align-items: center;
  gap: 4px;
}

.vol-btn {
  width: 26px;
  height: 26px;
}

.volume-slider-wrapper {
  width: 72px;
  display: flex;
  align-items: center;
}

.volume-slider {
  width: 100%;
  height: 3px;
  -webkit-appearance: none;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 2px;
  outline: none;
  cursor: pointer;
}

.volume-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #ffffff;
  cursor: pointer;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
}
</style>