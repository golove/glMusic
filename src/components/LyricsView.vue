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
      <div class="header-left">
        <!-- Translation Toggle -->
        <button
          class="header-tool-btn"
          :class="{ active: player.showLyricTranslation.value }"
          @click="player.toggleLyricTranslation()"
          title="显示/隐藏翻译"
        >
          <Languages :size="17" />
          <span>译</span>
        </button>

        <!-- Font Size Toggle -->
        <button
          class="header-tool-btn"
          :class="{ active: player.largeLyricText.value }"
          @click="player.toggleLargeLyricText()"
          title="切换大字号"
        >
          <Type :size="17" />
          <span>{{ player.largeLyricText.value ? '标准' : '大字' }}</span>
        </button>
      </div>

      <!-- Close Button -->
      <button class="close-btn" @click="player.isShowingLyrics.value = false" title="关闭歌词 (Esc)">
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
          <h2
            class="track-title link-text"
            :title="player.currentSong.value?.name"
            @click="player.currentSong.value?.album.id && (player.isShowingLyrics.value = false, player.navigate('album', player.currentSong.value.album.id))"
          >
            {{ player.currentSong.value?.name || '未知歌曲' }}
          </h2>
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

          <div class="badges-row">
            <span class="badge">{{ player.soundQuality.value.toUpperCase() }}</span>
            <span class="badge" v-if="player.currentSong.value?.durationText">{{ player.currentSong.value.durationText }}</span>
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
import { ChevronDown, Loader2, Languages, Type, Disc3 } from 'lucide-vue-next';
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

function handleKeyDown(e: KeyboardEvent) {
  if (e.key === 'Escape') {
    player.isShowingLyrics.value = false;
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeyDown);
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyDown);
});
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
  padding: 18px 36px 8px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 10px;
}

.header-tool-btn {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 8px;
  color: #a1a1aa;
  padding: 6px 12px;
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.header-tool-btn:hover {
  background: rgba(255, 255, 255, 0.15);
  color: #ffffff;
}

.header-tool-btn.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #ffffff;
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
  padding: 10px 80px 60px;
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

.link-text {
  cursor: pointer;
  transition: color 0.15s ease;
}

.link-text:hover {
  color: var(--accent);
  text-decoration: underline;
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
  padding: 180px 0;
  mask-image: linear-gradient(to bottom, transparent 0%, black 15%, black 85%, transparent 100%);
  -webkit-mask-image: linear-gradient(to bottom, transparent 0%, black 15%, black 85%, transparent 100%);
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
  font-size: 16px;
}

.lyrics-scroll-list {
  display: flex;
  flex-direction: column;
  gap: 30px;
}

.lyrics-scroll-list.large-size .lyric-text {
  font-size: 38px;
}

.lyrics-scroll-list.large-size .lyric-trans {
  font-size: 21px;
}

.lyric-line {
  cursor: pointer;
  opacity: 0.28;
  transform: scale(0.96);
  transform-origin: left center;
  transition: all 0.35s cubic-bezier(0.2, 0.8, 0.2, 1);
  padding: 6px 12px;
  border-radius: 10px;
}

.lyric-line:hover {
  opacity: 0.65;
  background: rgba(255, 255, 255, 0.05);
}

.lyric-line.active {
  opacity: 1;
  transform: scale(1.06);
  text-shadow: 0 0 25px var(--accent);
}

.lyric-text {
  font-size: 30px;
  font-weight: 700;
  color: #ffffff;
  margin: 0;
  line-height: 1.35;
  letter-spacing: -0.4px;
}

.lyric-trans {
  font-size: 16px;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.7);
  margin-top: 6px;
  margin-bottom: 0;
}

.spin-icon {
  animation: spin 1s linear infinite;
}

.spin-disc {
  animation: spin 12s linear infinite;
  color: var(--accent);
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
