<template>
  <div class="view-container">
    <div class="header-section">
      <h1 class="view-title">播放历史</h1>
      <p class="view-subtitle">最近播放的本地与云端歌曲 · 共 {{ player.history.value.length }} 首</p>

      <div class="actions-row" v-if="player.history.value.length > 0">
        <button class="primary-capsule-btn" @click="playAll">
          <Play :size="14" fill="#ffffff" />
          <span>播放全部</span>
        </button>
        <button class="secondary-capsule-btn" @click="clearHistory">
          <Trash2 :size="14" />
          <span>清空历史</span>
        </button>
      </div>
    </div>

    <div v-if="player.history.value.length === 0" class="empty-state">
      <Clock :size="48" class="empty-icon" />
      <span>暂无播放记录，快去探索好歌吧</span>
    </div>

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
        v-for="(song, idx) in player.history.value"
        :key="`${song.id}-${idx}`"
        :class="['table-row', { active: player.currentSong.value?.id === song.id }]"
        @click="player.play(song, player.history.value)"
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
import { Play, Trash2, Clock, Heart } from 'lucide-vue-next';
import { player } from '../stores/player';
import { api } from '../services/api';

function playAll() {
  if (player.history.value.length > 0) {
    player.play(player.history.value[0], player.history.value);
  }
}

async function clearHistory() {
  player.history.value = [];
  await api.saveLocalHistory([]);
}
</script>

<style scoped>
.view-container {
  padding: 30px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 28px;
}

.header-section {
  display: flex;
  flex-direction: column;
  gap: 6px;
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

.primary-capsule-btn:hover {
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

.secondary-capsule-btn:hover {
  background: rgba(255, 255, 255, 0.16);
  transform: scale(1.03);
}

.empty-state {
  height: 280px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 14px;
  color: #71717a;
  font-size: 14px;
}

.empty-icon {
  color: rgba(255, 255, 255, 0.2);
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