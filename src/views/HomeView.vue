<template>
  <div class="view-container">
    <!-- Header Title (Apple Music "现在就听") -->
    <div class="header-section">
      <h1 class="view-title">现在就听</h1>
      <p class="view-subtitle">为你精选网易云每日推荐与热门好歌</p>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>加载精彩内容...</span>
    </div>

    <template v-else>
      <!-- Featured Banners Carousel (Apple Music Top Hero Cards) -->
      <div v-if="banners.length > 0" class="banners-carousel">
        <div
          v-for="(banner, idx) in banners"
          :key="idx"
          class="banner-card"
          @click="handleBannerClick(banner)"
        >
          <img :src="banner.imageUrl" class="banner-img" alt="Banner" loading="lazy" />
          <div class="banner-overlay">
            <span class="banner-badge" v-if="banner.typeTitle">{{ banner.typeTitle }}</span>
            <div class="banner-play-hint">
              <Play :size="16" fill="#fff" />
            </div>
          </div>
        </div>
      </div>

      <!-- Section: 推荐歌单 -->
      <div class="content-section" v-if="playlists.length > 0">
        <div class="section-header">
          <div class="section-title-wrap">
            <h2 class="section-title">推荐歌单</h2>
            <span class="section-desc">根据你的听歌习惯推荐</span>
          </div>
          <button class="more-btn" @click="player.navigate('playlistSquare')">查看全部</button>
        </div>

        <div class="playlist-grid">
          <div
            v-for="item in playlists"
            :key="item.id"
            class="playlist-card"
          >
            <div class="cover-box" @click="player.navigate('playlist', item.id)">
              <img :src="item.coverImgUrl" class="cover-img" alt="" loading="lazy" />

              <!-- Hover Play Button (Mac Apple Music Style) -->
              <button
                class="hover-play-btn"
                @click.stop="playPlaylistDirectly(item.id)"
                title="播放此歌单"
              >
                <Play :size="15" fill="#ffffff" style="margin-left: 2px;" />
              </button>

              <!-- Play Count Badge -->
              <div class="play-count-badge" v-if="item.playCount">
                <Headphones :size="11" />
                <span>{{ formatPlayCount(item.playCount) }}</span>
              </div>
            </div>

            <!-- Title & Subtitle -->
            <div class="playlist-info" @click="player.navigate('playlist', item.id)">
              <div class="playlist-name" :title="item.name">{{ item.name }}</div>
              <div class="playlist-count">{{ item.trackCount ? `${item.trackCount} 首歌曲` : '精选歌单' }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Section: 新歌速递 (Apple Music 2-Column List) -->
      <div class="content-section" v-if="newSongs.length > 0">
        <div class="section-header">
          <div class="section-title-wrap">
            <h2 class="section-title">新歌速递</h2>
            <span class="section-desc">编辑精选最新单曲</span>
          </div>
          <button class="play-all-btn" @click="playAllNewSongs">
            <Play :size="13" fill="#ffffff" />
            <span>播放全部</span>
          </button>
        </div>

        <div class="songs-two-columns">
          <div
            v-for="(song, idx) in newSongs.slice(0, 12)"
            :key="song.id"
            :class="['song-row-card', { active: player.currentSong.value?.id === song.id }]"
            @click="player.play(song, newSongs)"
          >
            <!-- Index / Animated Playing Bars -->
            <div class="row-index">
              <span v-if="player.currentSong.value?.id === song.id && player.isPlaying.value" class="equalizer-icon">
                <span class="eq-bar bar-1"></span>
                <span class="eq-bar bar-2"></span>
                <span class="eq-bar bar-3"></span>
              </span>
              <Play v-else class="play-hint-icon" :size="11" fill="currentColor" />
              <span class="num-text">{{ idx + 1 }}</span>
            </div>

            <!-- Thumbnail -->
            <img :src="song.album.picUrl" class="song-thumb" alt="" loading="lazy" />

            <!-- Track Meta -->
            <div class="song-info">
              <span class="song-name" :title="song.name">{{ song.name }}</span>
              <span class="song-artist" :title="song.artistText">{{ song.artistText }}</span>
            </div>

            <!-- Like & Duration -->
            <div class="song-right-actions">
              <button
                class="row-like-btn"
                :class="{ active: player.likedSongIds.value.has(song.id) }"
                @click.stop="player.toggleLike(song)"
              >
                <Heart :size="14" :fill="player.likedSongIds.value.has(song.id) ? 'var(--accent)' : 'none'" />
              </button>
              <span class="song-duration">{{ song.durationText }}</span>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Play, Headphones, Heart, Loader2 } from 'lucide-vue-next';
import { api } from '../services/api';
import { player } from '../stores/player';
import type { BannerItem, Playlist, Song } from '../types/music';

const banners = ref<BannerItem[]>([]);
const playlists = ref<Playlist[]>([]);
const newSongs = ref<Song[]>([]);
const isLoading = ref(true);

onMounted(async () => {
  try {
    const [b, p, s] = await Promise.all([
      api.getBanners(),
      api.getPersonalizedPlaylists(10),
      api.getPersonalizedNewSongs(12)
    ]);
    banners.value = b;
    playlists.value = p;
    newSongs.value = s;
  } catch (e) {
    console.error('Home load error', e);
  } finally {
    isLoading.value = false;
  }
});

function handleBannerClick(banner: BannerItem) {
  if (banner.targetType === 1 && banner.targetId) {
    // Song
    api.getSongDetail([banner.targetId]).then(songs => {
      if (songs.length > 0) player.play(songs[0]);
    });
  } else if (banner.targetType === 10 && banner.targetId) {
    // Album
    player.navigate('album', banner.targetId);
  } else if (banner.targetType === 1000 && banner.targetId) {
    // Playlist
    player.navigate('playlist', banner.targetId);
  }
}

async function playPlaylistDirectly(playlistId: number) {
  try {
    const songs = await api.getPlaylistTracks(playlistId, 50);
    if (songs && songs.length > 0) {
      player.play(songs[0], songs);
    }
  } catch (e) {
    console.error('Play playlist error', e);
  }
}

function playAllNewSongs() {
  if (newSongs.value.length > 0) {
    player.play(newSongs.value[0], newSongs.value);
  }
}

function formatPlayCount(count: number): string {
  if (count > 100000000) return `${(count / 100000000).toFixed(1)}亿`;
  if (count > 10000) return `${Math.floor(count / 10000)}万`;
  return count.toString();
}
</script>

<style scoped>
.view-container {
  padding: 30px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 36px;
}

.header-section {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.view-title {
  margin: 0;
  font-size: 32px;
  font-weight: 800;
  color: #ffffff;
  letter-spacing: -0.6px;
}

.view-subtitle {
  margin: 0;
  font-size: 13px;
  color: #71717a;
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 80px 0;
  color: #a1a1aa;
  font-size: 14px;
}

.spin-icon {
  animation: spin 1s linear infinite;
  color: var(--accent);
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* Banners */
.banners-carousel {
  display: flex;
  gap: 18px;
  overflow-x: auto;
  padding-bottom: 6px;
  scrollbar-width: none;
}

.banners-carousel::-webkit-scrollbar {
  display: none;
}

.banner-card {
  position: relative;
  flex: 0 0 360px;
  height: 165px;
  border-radius: 12px;
  overflow: hidden;
  cursor: pointer;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.banner-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 12px 28px rgba(0, 0, 0, 0.5);
}

.banner-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.banner-overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, transparent 60%, rgba(0, 0, 0, 0.6) 100%);
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding: 12px;
}

.banner-badge {
  font-size: 11px;
  font-weight: 600;
  padding: 3px 8px;
  border-radius: 6px;
  background: rgba(0, 0, 0, 0.65);
  color: #ffffff;
  backdrop-filter: blur(8px);
}

.banner-play-hint {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: var(--accent);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transform: scale(0.85);
  transition: all 0.2s ease;
}

.banner-card:hover .banner-play-hint {
  opacity: 1;
  transform: scale(1);
}

/* Sections */
.content-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.section-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
}

.section-title-wrap {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.section-title {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: #ffffff;
  letter-spacing: -0.3px;
}

.section-desc {
  font-size: 12px;
  color: #71717a;
}

.more-btn {
  background: transparent;
  border: none;
  color: var(--accent);
  font-size: 12.5px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.15s ease;
}

.more-btn:hover {
  opacity: 0.8;
}

.play-all-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 14px;
  border-radius: 20px;
  background: var(--accent);
  border: none;
  color: #ffffff;
  font-size: 12.5px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.15s ease;
  box-shadow: 0 4px 12px color-mix(in srgb, var(--accent) 35%, transparent);
}

.play-all-btn:hover {
  transform: scale(1.04);
}

/* Playlist Grid */
.playlist-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(170px, 1fr));
  gap: 20px;
}

.playlist-card {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.cover-box {
  position: relative;
  width: 100%;
  aspect-ratio: 1 / 1;
  border-radius: 10px;
  overflow: hidden;
  cursor: pointer;
  background: #1e2026;
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.35);
  transition: transform 0.22s ease, box-shadow 0.22s ease;
}

.cover-box:hover {
  transform: scale(1.03);
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.5);
}

.cover-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.hover-play-btn {
  position: absolute;
  bottom: 10px;
  right: 10px;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: var(--accent);
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
  opacity: 0;
  transform: scale(0.85);
  transition: all 0.18s cubic-bezier(0.2, 0.8, 0.2, 1);
}

.cover-box:hover .hover-play-btn {
  opacity: 1;
  transform: scale(1);
}

.hover-play-btn:hover {
  transform: scale(1.1) !important;
}

.play-count-badge {
  position: absolute;
  top: 8px;
  right: 8px;
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 2px 7px;
  border-radius: 10px;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(6px);
  color: #ffffff;
  font-size: 10.5px;
  font-weight: 500;
}

.playlist-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  cursor: pointer;
}

.playlist-name {
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  line-height: 1.35;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
}

.playlist-count {
  font-size: 11px;
  color: #71717a;
}

/* Two Columns Songs List */
.songs-two-columns {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px 18px;
}

@media (max-width: 900px) {
  .songs-two-columns {
    grid-template-columns: 1fr;
  }
}

.song-row-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 6px 10px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.16s ease;
}

.song-row-card:hover {
  background: rgba(255, 255, 255, 0.08);
}

.song-row-card.active {
  background: rgba(255, 255, 255, 0.12);
}

.row-index {
  width: 20px;
  text-align: center;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #71717a;
}

.play-hint-icon {
  display: none;
  color: #ffffff;
}

.song-row-card:hover .num-text {
  display: none;
}

.song-row-card:hover .play-hint-icon {
  display: block;
}

.equalizer-icon {
  display: flex;
  align-items: flex-end;
  gap: 2px;
  height: 12px;
}

.eq-bar {
  width: 2px;
  background: var(--accent);
  border-radius: 1px;
  animation: eqBounce 0.8s ease-in-out infinite alternate;
}

.bar-1 { height: 8px; animation-delay: 0.1s; }
.bar-2 { height: 12px; animation-delay: 0.3s; }
.bar-3 { height: 6px; animation-delay: 0.2s; }

@keyframes eqBounce {
  from { height: 3px; }
  to { height: 12px; }
}

.song-thumb {
  width: 44px;
  height: 44px;
  border-radius: 6px;
  object-fit: cover;
  flex-shrink: 0;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.3);
}

.song-info {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
  gap: 2px;
}

.song-name {
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.song-row-card.active .song-name {
  color: var(--accent);
}

.song-artist {
  font-size: 11.5px;
  color: #a1a1aa;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.song-right-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.row-like-btn {
  background: transparent;
  border: none;
  color: #71717a;
  cursor: pointer;
  padding: 4px;
  display: flex;
  align-items: center;
  opacity: 0;
  transition: opacity 0.15s ease, transform 0.15s ease;
}

.song-row-card:hover .row-like-btn,
.row-like-btn.active {
  opacity: 1;
}

.row-like-btn:hover {
  transform: scale(1.15);
  color: #ffffff;
}

.row-like-btn.active {
  color: var(--accent);
}

.song-duration {
  font-size: 11.5px;
  color: #71717a;
  font-variant-numeric: tabular-nums;
  min-width: 32px;
  text-align: right;
}
</style>