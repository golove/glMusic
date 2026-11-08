<template>
  <div class="view-container">
    <div class="header-section">
      <h2 class="view-title">发现音乐</h2>
      <p class="view-subtitle">为你精选网易云每日推荐与热门好歌</p>
    </div>

    <!-- Banners Slider -->
    <div v-if="banners.length > 0" class="banners-carousel">
      <div
        v-for="(banner, idx) in banners.slice(0, 5)"
        :key="idx"
        class="banner-card"
        @click="handleBannerClick(banner)"
      >
        <img :src="banner.imageUrl" class="banner-img" alt="Banner" />
        <span class="banner-badge">{{ banner.typeTitle }}</span>
      </div>
    </div>

    <!-- Section: 推荐歌单 -->
    <div class="content-section">
      <div class="section-header">
        <h3 class="section-title">推荐歌单</h3>
        <button class="more-btn" @click="player.navigate('playlistSquare')">查看全部</button>
      </div>

      <div class="playlist-grid">
        <div
          v-for="item in playlists"
          :key="item.id"
          class="playlist-card"
          @click="player.navigate('playlist', item.id)"
        >
          <div class="cover-box">
            <img :src="item.coverImgUrl" class="cover-img" alt="" loading="lazy" />
            <div class="play-overlay">
              <Play :size="22" fill="#fff" />
            </div>
            <div class="play-count" v-if="item.playCount">
              <Headphones :size="12" />
              <span>{{ formatPlayCount(item.playCount) }}</span>
            </div>
          </div>
          <div class="playlist-name" :title="item.name">{{ item.name }}</div>
        </div>
      </div>
    </div>

    <!-- Section: 推荐新歌 -->
    <div class="content-section">
      <div class="section-header">
        <h3 class="section-title">最新单曲</h3>
        <button class="more-btn" @click="playAllNewSongs">播放全部</button>
      </div>

      <div class="songs-grid">
        <div
          v-for="song in newSongs"
          :key="song.id"
          class="song-row-item"
          @click="player.play(song, newSongs)"
        >
          <img :src="song.album.picUrl" class="song-thumb" alt="" />
          <div class="song-info">
            <span class="song-name">{{ song.name }}</span>
            <span class="song-artist">{{ song.artistText }}</span>
          </div>
          <span class="song-duration">{{ song.durationText }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Play, Headphones } from 'lucide-vue-next';
import { api } from '../services/api';
import { player } from '../stores/player';
import type { BannerItem, Playlist, Song } from '../types/music';

const banners = ref<BannerItem[]>([]);
const playlists = ref<Playlist[]>([]);
const newSongs = ref<Song[]>([]);

onMounted(async () => {
  try {
    const [b, p, s] = await Promise.all([
      api.getBanners(),
      api.getPersonalizedPlaylists(8),
      api.getPersonalizedNewSongs(10)
    ]);
    banners.value = b;
    playlists.value = p;
    newSongs.value = s;
  } catch (e) {
    console.error('Home load error', e);
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
  padding: 32px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 32px;
}

.header-section {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.view-title {
  margin: 0;
  font-size: 28px;
  font-weight: 800;
  color: #ffffff;
  letter-spacing: -0.6px;
}

.view-subtitle {
  margin: 0;
  font-size: 13px;
  color: #71717a;
}

/* Banners */
.banners-carousel {
  display: flex;
  gap: 16px;
  overflow-x: auto;
  padding-bottom: 8px;
  scrollbar-width: none;
}

.banners-carousel::-webkit-scrollbar {
  display: none;
}

.banner-card {
  position: relative;
  flex: 0 0 320px;
  height: 160px;
  border-radius: 14px;
  overflow: hidden;
  cursor: pointer;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
  transition: transform 0.2s ease;
}

.banner-card:hover {
  transform: translateY(-4px);
}

.banner-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.banner-badge {
  position: absolute;
  bottom: 10px;
  right: 10px;
  font-size: 11px;
  padding: 2px 7px;
  border-radius: 6px;
  background: rgba(0, 0, 0, 0.7);
  color: #ffffff;
  backdrop-filter: blur(8px);
}

/* Sections */
.content-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.section-title {
  margin: 0;
  font-size: 19px;
  font-weight: 700;
  color: #ffffff;
}

.more-btn {
  background: transparent;
  border: none;
  color: #8b8b93;
  font-size: 13px;
  cursor: pointer;
  transition: color 0.15s ease;
}

.more-btn:hover {
  color: #ffffff;
}

/* Playlist Grid */
.playlist-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 20px;
}

.playlist-card {
  display: flex;
  flex-direction: column;
  gap: 8px;
  cursor: pointer;
}

.cover-box {
  position: relative;
  width: 100%;
  aspect-ratio: 1;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.35);
  background: rgba(255, 255, 255, 0.05);
}

.cover-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.25s ease;
}

.playlist-card:hover .cover-img {
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

.playlist-card:hover .play-overlay {
  opacity: 1;
}

.play-count {
  position: absolute;
  top: 8px;
  right: 8px;
  background: rgba(0, 0, 0, 0.65);
  backdrop-filter: blur(6px);
  padding: 2px 7px;
  border-radius: 10px;
  font-size: 10.5px;
  color: #ffffff;
  display: flex;
  align-items: center;
  gap: 4px;
}

.playlist-name {
  font-size: 13.5px;
  font-weight: 500;
  color: #e4e4e7;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4;
}

/* Songs Grid */
.songs-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 10px;
}

.song-row-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.04);
  cursor: pointer;
  transition: all 0.15s ease;
}

.song-row-item:hover {
  background: rgba(255, 255, 255, 0.1);
  transform: translateY(-2px);
}

.song-thumb {
  width: 44px;
  height: 44px;
  border-radius: 8px;
  object-fit: cover;
}

.song-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  gap: 3px;
}

.song-name {
  font-size: 13.5px;
  font-weight: 600;
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

.song-duration {
  font-size: 12px;
  color: #71717a;
}
</style>
