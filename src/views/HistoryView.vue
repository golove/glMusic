<template>
  <div class="view-container">
    <div class="header-section">
      <h2 class="view-title">播放历史</h2>
      <p class="view-subtitle">最近播放的本地与云端歌曲 (共 {{ player.history.value.length }} 首)</p>

      <div class="actions-row" v-if="player.history.value.length > 0">
        <button class="primary-btn" @click="playAll">
          <Play :size="16" fill="#fff" />
          <span>播放全部</span>
        </button>
        <button class="secondary-btn" @click="clearHistory">
          <Trash2 :size="15" />
          <span>清空历史</span>
        </button>
      </div>
    </div>

    <div v-if="player.history.value.length === 0" class="empty-state">
      <Clock :size="48" />
      <span>暂无播放记录，快去探索好歌吧</span>
    </div>

    <div v-else class="song-table">
      <div class="table-header">
        <span class="col-index">#</span>
        <span class="col-title">标题</span>
        <span class="col-album">专辑</span>
        <span class="col-actions">操作</span>
        <span class="col-duration">时长</span>
      </div>

      <div
        v-for="(song, idx) in player.history.value"
        :key="`${song.id}-${idx}`"
        :class="['table-row', { active: player.currentSong.value?.id === song.id }]"
        @click="player.play(song, player.history.value)"
      >
        <span class="col-index">{{ idx + 1 }}</span>
        <div class="col-title song-title-cell">
          <img :src="song.album.picUrl" class="cell-thumb" alt="" />
          <div class="title-meta">
            <span class="song-name">{{ song.name }}</span>
            <span class="song-artist">{{ song.artistText }}</span>
          </div>
        </div>
        <span class="col-album" :title="song.album.name">{{ song.album.name }}</span>
        <div class="col-actions" @click.stop>
          <button class="action-btn" @click="player.toggleLike(song)">
            <Heart
              :size="16"
              :fill="player.likedSongIds.value.has(song.id) ? 'var(--accent)' : 'none'"
              :color="player.likedSongIds.value.has(song.id) ? 'var(--accent)' : '#8b8b93'"
            />
          </button>
        </div>
        <span class="col-duration">{{ song.durationText }}</span>
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
  padding: 32px 36px 120px;
  display: flex;
  flex-direction: column;
  gap: 28px;
}

.header-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.view-title {
  margin: 0;
  font-size: 28px;
  font-weight: 800;
  color: #ffffff;
}

.view-subtitle {
  margin: 0;
  font-size: 13px;
  color: #71717a;
}

.actions-row {
  display: flex;
  gap: 12px;
  margin-top: 8px;
}

.primary-btn {
  background: var(--accent);
  border: none;
  border-radius: 20px;
  color: #ffffff;
  font-size: 13.5px;
  font-weight: 600;
  padding: 8px 18px;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  box-shadow: 0 4px 16px rgba(0, 113, 227, 0.4);
}

.secondary-btn {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 20px;
  color: #d4d4d8;
  font-size: 13.5px;
  padding: 8px 16px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.secondary-btn:hover {
  background: rgba(255, 255, 255, 0.15);
  color: #ffffff;
}

.empty-state {
  height: 300px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  color: #71717a;
  font-size: 15px;
}

/* Song Table */
.song-table {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.table-header {
  display: grid;
  grid-template-columns: 40px 1fr 240px 60px 70px;
  align-items: center;
  padding: 10px 14px;
  font-size: 12px;
  color: #71717a;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  font-weight: 600;
}

.table-row {
  display: grid;
  grid-template-columns: 40px 1fr 240px 60px 70px;
  align-items: center;
  padding: 8px 14px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.15s ease;
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
  color: #71717a;
  font-size: 12px;
}

.song-title-cell {
  display: flex;
  align-items: center;
  gap: 12px;
  overflow: hidden;
}

.cell-thumb {
  width: 40px;
  height: 40px;
  border-radius: 6px;
  object-fit: cover;
  flex-shrink: 0;
}

.title-meta {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  gap: 2px;
}

.song-name {
  font-size: 13.5px;
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

.col-album {
  font-size: 12.5px;
  color: #a1a1aa;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.col-duration {
  font-size: 12px;
  color: #71717a;
}

.action-btn {
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 4px;
  display: flex;
  align-items: center;
}
</style>
