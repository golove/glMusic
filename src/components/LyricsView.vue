<template>
  <div class="lyrics-view-overlay" :style="{ '--accent': player.accentColor.value }">
    <!-- Blurred Album Art Backdrop -->
    <div
      class="backdrop-art"
      :style="{ backgroundImage: `url(${player.currentSong.value?.album.picUrl || ''})` }"
    ></div>
    <div class="backdrop-mask"></div>

    <!-- Header Actions -->
    <div class="lyrics-header">
      <button class="close-btn" @click="player.isShowingLyrics.value = false" title="关闭歌词">
        <ChevronDown :size="24" />
      </button>
    </div>

    <!-- Main Content Grid -->
    <div class="lyrics-content">
      <!-- Left Column: Album Artwork & Metadata -->
      <div class="cover-column">
        <div class="artwork-card">
          <img
            :src="player.currentSong.value?.album.picUrl || 'https://p1.music.126.net/6y-UleORITEDbvrOLj0QGg==/109951163077757723.jpg'"
            class="cover-image"
            alt="Album Cover"
          />
        </div>
        <div class="track-details">
          <h2 class="track-title">{{ player.currentSong.value?.name || '未知歌曲' }}</h2>
          <p class="track-artist">{{ player.currentSong.value?.artistText || '未知歌手' }}</p>
          <p class="track-album">{{ player.currentSong.value?.album.name || '未知专辑' }}</p>

          <div class="badges-row">
            <span class="badge">{{ player.soundQuality.value.toUpperCase() }}</span>
            <span class="badge" v-if="player.currentSong.value?.durationText">{{ player.currentSong.value.durationText }}</span>
          </div>
        </div>
      </div>

      <!-- Right Column: Karaoke Synced Lyrics -->
      <div class="lyrics-column" ref="lyricsContainer">
        <div v-if="player.isLoadingLyrics.value" class="lyrics-status">
          <Loader2 class="spin-icon" :size="28" />
          <span>正在加载歌词...</span>
        </div>
        <div v-else-if="player.lyrics.value.length === 0" class="lyrics-status">
          <span>暂无歌词</span>
        </div>
        <div v-else class="lyrics-scroll-list">
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
            <p v-if="line.translation" class="lyric-trans">{{ line.translation }}</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, nextTick } from 'vue';
import { ChevronDown, Loader2 } from 'lucide-vue-next';
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

// Auto scroll to current lyric line
watch(
  () => player.currentLyricIndex.value,
  (newIdx) => {
    nextTick(() => {
      const activeEl = lineElements.value[newIdx];
      const container = lyricsContainer.value;
      if (activeEl && container) {
        const offset = activeEl.offsetTop - container.offsetTop - container.clientHeight / 2 + activeEl.clientHeight / 2;
        container.scrollTo({
          top: offset,
          behavior: 'smooth'
        });
      }
    });
  }
);
</script>

<style scoped>
.lyrics-view-overlay {
  position: fixed;
  inset: 0;
  z-index: 999;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  user-select: none;
  background-color: #0c0d10;
  animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes fadeIn {
  from { opacity: 0; transform: scale(0.98); }
  to { opacity: 1; transform: scale(1); }
}

.backdrop-art {
  position: absolute;
  inset: -60px;
  background-size: cover;
  background-position: center;
  filter: blur(80px) saturate(220%) brightness(0.45);
  transform: scale(1.2);
  z-index: 0;
}

.backdrop-mask {
  position: absolute;
  inset: 0;
  background: radial-gradient(circle at 40% 50%, rgba(15, 17, 23, 0.65) 0%, rgba(10, 11, 14, 0.92) 100%);
  z-index: 1;
}

.lyrics-header {
  position: relative;
  z-index: 10;
  padding: 24px 32px 10px;
  display: flex;
  justify-content: flex-end;
}

.close-btn {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 50%;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #ffffff;
  cursor: pointer;
  transition: all 0.2s ease;
}

.close-btn:hover {
  background: rgba(255, 255, 255, 0.22);
  transform: scale(1.08);
}

.lyrics-content {
  position: relative;
  z-index: 10;
  flex: 1;
  display: flex;
  padding: 20px 80px 60px;
  gap: 80px;
  overflow: hidden;
}

/* Left Cover Column */
.cover-column {
  flex: 0 0 380px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: flex-start;
  gap: 28px;
}

.artwork-card {
  width: 360px;
  height: 360px;
  border-radius: 20px;
  overflow: hidden;
  box-shadow: 0 24px 50px rgba(0, 0, 0, 0.65);
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

.track-title {
  font-size: 26px;
  font-weight: 700;
  color: #ffffff;
  margin: 0;
  letter-spacing: -0.5px;
}

.track-artist {
  font-size: 17px;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.8);
  margin: 0;
}

.track-album {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.5);
  margin: 0;
}

.badges-row {
  display: flex;
  gap: 8px;
  margin-top: 8px;
}

.badge {
  font-size: 11px;
  font-weight: 700;
  padding: 3px 8px;
  border-radius: 5px;
  background: rgba(255, 255, 255, 0.12);
  color: #ffffff;
  letter-spacing: 0.5px;
}

/* Right Lyrics Column */
.lyrics-column {
  flex: 1;
  overflow-y: auto;
  scroll-behavior: smooth;
  padding: 160px 0;
  mask-image: linear-gradient(to bottom, transparent 0%, black 18%, black 82%, transparent 100%);
  -webkit-mask-image: linear-gradient(to bottom, transparent 0%, black 18%, black 82%, transparent 100%);
}

.lyrics-column::-webkit-scrollbar {
  display: none;
}

.lyrics-status {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  color: rgba(255, 255, 255, 0.5);
  font-size: 18px;
}

.lyrics-scroll-list {
  display: flex;
  flex-direction: column;
  gap: 32px;
}

.lyric-line {
  cursor: pointer;
  opacity: 0.28;
  transform: scale(0.96);
  transform-origin: left center;
  transition: all 0.35s cubic-bezier(0.2, 0.8, 0.2, 1);
  padding: 4px 8px;
  border-radius: 8px;
}

.lyric-line:hover {
  opacity: 0.65;
}

.lyric-line.active {
  opacity: 1;
  transform: scale(1.05);
  text-shadow: 0 0 30px var(--accent);
}

.lyric-text {
  font-size: 32px;
  font-weight: 700;
  color: #ffffff;
  margin: 0;
  line-height: 1.35;
  letter-spacing: -0.5px;
}

.lyric-trans {
  font-size: 18px;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.7);
  margin-top: 6px;
  margin-bottom: 0;
}

.spin-icon {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
