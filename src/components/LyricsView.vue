<template>
  <div class="lyrics-view-overlay" :style="{ '--accent': player.accentColor.value }">
    <!-- Blurred Album Art Backdrop -->
    <div
      class="backdrop-art"
      :style="{ backgroundImage: `url(${player.currentSong.value?.album.picUrl || ''})` }"
    ></div>
    <div class="backdrop-mask"></div>

    <!-- Header Actions (Top Bar) -->
    <div class="lyrics-header">
      <!-- Top Left: Rounded Return Button (Matching Mac glMusic LyricsView) -->
      <button
        class="return-circle-btn"
        @click="player.isShowingLyrics.value = false"
        title="返回 (Esc)"
      >
        <ChevronDown :size="18" />
      </button>

      <!-- Top Right: Lyrics Display Controls -->
      <div class="header-right-tools">
        <!-- Translation Toggle -->
        <button
          class="tool-pill-btn"
          :class="{ active: player.showLyricTranslation.value }"
          @click="player.toggleLyricTranslation()"
          title="显示/隐藏歌词翻译"
        >
          <Languages :size="15" />
          <span>译</span>
        </button>

        <!-- Font Size Toggle -->
        <button
          class="tool-pill-btn"
          :class="{ active: player.largeLyricText.value }"
          @click="player.toggleLargeLyricText()"
          title="切换大字号"
        >
          <Type :size="15" />
          <span>{{ player.largeLyricText.value ? '标准' : '大字' }}</span>
        </button>
      </div>
    </div>

    <!-- Main Content Grid -->
    <div class="lyrics-content">
      <!-- Left Column: Album Artwork, Track Metadata & Full Playback Controls -->
      <div class="cover-column">
        <!-- Artwork Card -->
        <div class="artwork-card">
          <img
            :src="player.currentSong.value?.album.picUrl || 'https://p1.music.126.net/6y-UleORITEDbvrOLj0QGg==/109951163077757723.jpg'"
            class="cover-image"
            alt="Album Cover"
          />
        </div>

        <!-- Track Info -->
        <div class="track-details">
          <div class="title-row">
            <h1
              class="track-title link-text"
              :title="player.currentSong.value?.name"
              @click="player.currentSong.value?.album.id && (player.isShowingLyrics.value = false, player.navigate('album', player.currentSong.value.album.id))"
            >
              {{ player.currentSong.value?.name || '未知歌曲' }}
            </h1>

            <button
              v-if="player.currentSong.value"
              class="lyrics-like-btn"
              :class="{ active: player.likedSongIds.value.has(player.currentSong.value.id) }"
              @click="player.toggleLike(player.currentSong.value)"
              :title="player.likedSongIds.value.has(player.currentSong.value.id) ? '取消喜欢' : '喜欢这首歌'"
            >
              <Heart :size="20" :fill="player.likedSongIds.value.has(player.currentSong.value.id) ? 'var(--accent)' : 'none'" />
            </button>
          </div>

          <p
            class="track-artist link-text"
            :title="player.currentSong.value?.artistText"
            @click="player.currentSong.value?.artists[0]?.id && (player.isShowingLyrics.value = false, player.navigate('artist', player.currentSong.value.artists[0].id))"
          >
            {{ player.currentSong.value?.artistText || '未知歌手' }}
          </p>

          <p
            class="track-album link-text"
            :title="player.currentSong.value?.album.name"
            @click="player.currentSong.value?.album.id && (player.isShowingLyrics.value = false, player.navigate('album', player.currentSong.value.album.id))"
          >
            {{ player.currentSong.value?.album.name || '未知专辑' }}
          </p>

          <!-- Badges -->
          <div class="badges-row">
            <span class="badge">{{ player.soundQuality.value.toUpperCase() }}</span>
            <span class="badge" v-if="player.currentSong.value?.durationText">{{ player.currentSong.value.durationText }}</span>
          </div>

          <!-- Progress Bar & Time Labels (Matching Mac Playback Controls in LyricsView) -->
          <div class="lyrics-progress-section">
            <div class="lyrics-slider-track" @click="onSliderClick">
              <div
                class="lyrics-slider-fill"
                :style="{ width: `${player.duration.value ? (player.currentTime.value / player.duration.value) * 100 : 0}%` }"
              ></div>
            </div>
            <div class="lyrics-time-row">
              <span>{{ formatTime(player.currentTime.value) }}</span>
              <span>{{ formatRemainingTime(player.duration.value, player.currentTime.value) }}</span>
            </div>
          </div>

          <!-- Playback Action Bar -->
          <div class="lyrics-controls-bar">
            <!-- Shuffle -->
            <button
              class="ctrl-btn"
              :class="{ active: player.isShuffled.value }"
              @click="player.toggleShuffle()"
              title="随机播放"
            >
              <Shuffle :size="16" />
            </button>

            <!-- Previous -->
            <button class="ctrl-btn" @click="player.previous()" title="上一首">
              <SkipBack :size="24" />
            </button>

            <!-- Play / Pause -->
            <button class="main-play-btn" @click="player.togglePlay()" title="播放/暂停">
              <Loader2 v-if="player.isLoading.value" class="spin-icon" :size="24" />
              <Pause v-else-if="player.isPlaying.value" :size="24" />
              <Play v-else :size="24" style="margin-left: 2px;" />
            </button>

            <!-- Next -->
            <button class="ctrl-btn" @click="player.next()" title="下一首">
              <SkipForward :size="24" />
            </button>

            <!-- Repeat -->
            <button
              class="ctrl-btn"
              :class="{ active: player.repeatMode.value !== 'off' }"
              @click="player.toggleRepeatMode()"
              title="循环模式"
            >
              <Repeat1 v-if="player.repeatMode.value === 'one'" :size="16" />
              <Repeat v-else :size="16" />
            </button>
          </div>
        </div>
      </div>

      <!-- Right Column: Karaoke Synced Lyrics -->
      <div class="lyrics-column" ref="lyricsContainer">
        <div v-if="player.isLoadingLyrics.value" class="lyrics-status">
          <Loader2 class="spin-icon" :size="32" />
          <span>正在加载歌词...</span>
        </div>
        <div v-else-if="player.lyrics.value.length === 0" class="lyrics-status">
          <Disc3 class="spin-disc" :size="48" />
          <span>纯音乐或暂无歌词，请尽情享受旋律</span>
        </div>
        <div v-else class="lyrics-scroll-list" :class="{ 'large-size': player.largeLyricText.value }">
          <div
            v-for="(line, idx) in player.lyrics.value"
            :key="idx"
            :ref="el => setLineRef(el, idx)"
            :class="[
              'lyric-line',
              { active: idx === player.currentLyricIndex.value },
              { past: idx < player.currentLyricIndex.value }
            ]"
            @click="seekToLine(line.time)"
          >
            <p class="lyric-text">{{ line.text }}</p>
            <p v-if="line.translation && player.showLyricTranslation.value" class="lyric-trans">
              {{ line.translation }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, nextTick, onMounted, onUnmounted } from 'vue';
import {
  ChevronDown,
  Loader2,
  Languages,
  Type,
  Disc3,
  Heart,
  Play,
  Pause,
  SkipBack,
  SkipForward,
  Shuffle,
  Repeat,
  Repeat1
} from 'lucide-vue-next';
import { player } from '../stores/player';

const lyricsContainer = ref<HTMLElement | null>(null);
const lineElements = ref<Record<number, HTMLElement>>({});

function setLineRef(el: any, idx: number) {
  if (el) {
    lineElements.value[idx] = el;
  }
}

function seekToLine(time: number) {
  player.seek(time);
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

function formatRemainingTime(total: number, cur: number): string {
  const remaining = Math.max(0, total - cur);
  return `-${formatTime(remaining)}`;
}

// Auto scroll lyrics smoothly
function scrollToActiveLine(index: number) {
  const activeEl = lineElements.value[index];
  const container = lyricsContainer.value;
  if (!activeEl || !container) return;

  const containerHeight = container.clientHeight;
  const elOffsetTop = activeEl.offsetTop;
  const elHeight = activeEl.clientHeight;

  // Center the active line vertically
  const targetScrollTop = elOffsetTop - containerHeight / 2 + elHeight / 2;

  container.scrollTo({
    top: Math.max(0, targetScrollTop),
    behavior: 'smooth'
  });
}

watch(() => player.currentLyricIndex.value, (newIdx) => {
  nextTick(() => {
    scrollToActiveLine(newIdx);
  });
});

onMounted(() => {
  nextTick(() => {
    scrollToActiveLine(player.currentLyricIndex.value);
  });
});

onUnmounted(() => {
  lineElements.value = {};
});
</script>

<style scoped>
.lyrics-view-overlay {
  position: fixed;
  inset: 0;
  z-index: 200;
  overflow: hidden;
  background-color: #121316;
  display: flex;
  flex-direction: column;
}

.backdrop-art {
  position: absolute;
  inset: -60px;
  background-size: cover;
  background-position: center;
  filter: blur(80px) saturate(160%) brightness(0.45);
  transform: scale(1.15);
  z-index: 0;
  pointer-events: none;
}

.backdrop-mask {
  position: absolute;
  inset: 0;
  background: radial-gradient(circle at 50% 50%, rgba(18, 19, 22, 0.4) 0%, rgba(18, 19, 22, 0.88) 100%);
  z-index: 1;
  pointer-events: none;
}

/* Header */
.lyrics-header {
  position: relative;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 28px;
}

.return-circle-btn {
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

.return-circle-btn:hover {
  transform: scale(1.08);
  background: color-mix(in srgb, var(--accent) 25%, rgba(255, 255, 255, 0.12));
}

.header-right-tools {
  display: flex;
  align-items: center;
  gap: 8px;
}

.tool-pill-btn {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 5px 12px;
  border-radius: 16px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: rgba(255, 255, 255, 0.06);
  color: #a1a1aa;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.16s ease;
}

.tool-pill-btn:hover {
  background: rgba(255, 255, 255, 0.12);
  color: #ffffff;
}

.tool-pill-btn.active {
  background: var(--accent);
  color: #ffffff;
  border-color: transparent;
}

/* Content Area */
.lyrics-content {
  position: relative;
  z-index: 5;
  flex: 1;
  display: flex;
  padding: 0 40px 40px 48px;
  gap: 48px;
  overflow: hidden;
}

/* Left: Cover & Details & Controls */
.cover-column {
  width: 340px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 20px;
}

.artwork-card {
  width: 280px;
  height: 280px;
  border-radius: 14px;
  overflow: hidden;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6), 0 0 40px color-mix(in srgb, var(--accent) 25%, transparent);
}

.cover-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.track-details {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.track-title {
  margin: 0;
  font-size: 24px;
  font-weight: 700;
  color: #ffffff;
  line-height: 1.25;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.lyrics-like-btn {
  background: transparent;
  border: none;
  color: #71717a;
  cursor: pointer;
  padding: 4px;
  display: flex;
  align-items: center;
  transition: transform 0.15s ease, color 0.15s ease;
}

.lyrics-like-btn:hover {
  transform: scale(1.15);
  color: #ffffff;
}

.lyrics-like-btn.active {
  color: var(--accent);
}

.track-artist {
  margin: 0;
  font-size: 14px;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.8);
}

.track-album {
  margin: 0;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.5);
}

.link-text {
  cursor: pointer;
  transition: color 0.15s ease;
}

.link-text:hover {
  color: #ffffff;
  text-decoration: underline;
}

.badges-row {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 4px;
}

.badge {
  font-size: 10px;
  font-weight: 600;
  padding: 2px 6px;
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.1);
  color: rgba(255, 255, 255, 0.7);
}

/* Lyrics Progress Bar */
.lyrics-progress-section {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-top: 12px;
  width: 280px;
}

.lyrics-slider-track {
  height: 4px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 2px;
  position: relative;
  cursor: pointer;
  transition: height 0.15s ease;
}

.lyrics-slider-track:hover {
  height: 6px;
}

.lyrics-slider-fill {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background: #ffffff;
  border-radius: 2px;
  pointer-events: none;
}

.lyrics-time-row {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.55);
  font-variant-numeric: tabular-nums;
}

/* Playback Controls Bar */
.lyrics-controls-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 280px;
  margin-top: 8px;
}

.ctrl-btn {
  background: transparent;
  border: none;
  color: rgba(255, 255, 255, 0.75);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 6px;
  border-radius: 50%;
  transition: all 0.15s ease;
}

.ctrl-btn:hover {
  color: #ffffff;
  transform: scale(1.1);
}

.ctrl-btn.active {
  color: var(--accent);
}

.main-play-btn {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  border: none;
  background: #ffffff;
  color: #000000;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.4);
  transition: transform 0.16s ease;
}

.main-play-btn:hover {
  transform: scale(1.08);
}

.spin-icon {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* Right: Scrolling Lyrics */
.lyrics-column {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 80px 20px 80px 0;
  display: flex;
  flex-direction: column;
  mask-image: linear-gradient(180deg, transparent 0%, rgba(0,0,0,1) 15%, rgba(0,0,0,1) 85%, transparent 100%);
  -webkit-mask-image: linear-gradient(180deg, transparent 0%, rgba(0,0,0,1) 15%, rgba(0,0,0,1) 85%, transparent 100%);
  scrollbar-width: none;
}

.lyrics-column::-webkit-scrollbar {
  display: none;
}

.lyrics-status {
  margin: auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  color: rgba(255, 255, 255, 0.5);
  font-size: 15px;
}

.spin-disc {
  animation: spin 6s linear infinite;
  color: rgba(255, 255, 255, 0.3);
}

.lyrics-scroll-list {
  display: flex;
  flex-direction: column;
  gap: 22px;
}

.lyric-line {
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.2, 0.8, 0.2, 1);
  opacity: 0.35;
  transform: scale(0.97);
  transform-origin: left center;
}

.lyric-line:hover {
  opacity: 0.7;
}

.lyric-line.active {
  opacity: 1;
  transform: scale(1.06);
  filter: drop-shadow(0 0 16px color-mix(in srgb, var(--accent) 60%, transparent));
}

.lyric-text {
  margin: 0;
  font-size: 26px;
  font-weight: 700;
  line-height: 1.35;
  color: #ffffff;
  letter-spacing: -0.3px;
}

.lyric-trans {
  margin: 6px 0 0 0;
  font-size: 18px;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.8);
  line-height: 1.35;
}

.large-size .lyric-text {
  font-size: 34px;
}

.large-size .lyric-trans {
  font-size: 22px;
}
</style>