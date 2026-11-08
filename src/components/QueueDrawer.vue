<template>
  <div v-if="player.isShowingQueue.value" class="queue-drawer-overlay" @click.self="player.isShowingQueue.value = false">
    <div class="queue-panel" :style="{ '--accent': player.accentColor.value }">
      <div class="queue-header">
        <div class="header-info">
          <h3 class="queue-title">播放队列</h3>
          <span class="queue-count">{{ player.queue.value.length }} 首歌曲</span>
        </div>
        <div class="header-actions">
          <button class="clear-btn" @click="clearQueue" title="清空队列">
            <Trash2 :size="15" />
            <span>清空</span>
          </button>
          <button class="icon-btn" @click="player.isShowingQueue.value = false">
            <X :size="18" />
          </button>
        </div>
      </div>

      <div class="queue-list">
        <div v-if="player.queue.value.length === 0" class="empty-state">
          <Music :size="36" />
          <p>当前队列为空</p>
        </div>
        <div
          v-for="(song, idx) in player.queue.value"
          :key="`${song.id}-${idx}`"
          :class="['queue-item', { active: player.currentSong.value?.id === song.id }]"
          @click="player.play(song)"
        >
          <div class="item-artwork">
            <img :src="song.album.picUrl" alt="" />
            <div v-if="player.currentSong.value?.id === song.id && player.isPlaying.value" class="playing-indicator">
              <span class="bar bar-1"></span>
              <span class="bar bar-2"></span>
              <span class="bar bar-3"></span>
            </div>
          </div>
          <div class="item-info">
            <span class="item-title">{{ song.name }}</span>
            <span class="item-artist">{{ song.artistText }}</span>
          </div>
          <span class="item-duration">{{ song.durationText }}</span>
          <button class="remove-btn" @click.stop="removeFromQueue(idx)">
            <X :size="13" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { X, Trash2, Music } from 'lucide-vue-next';
import { player } from '../stores/player';

function clearQueue() {
  player.queue.value = [];
  player.currentIndex.value = -1;
}

function removeFromQueue(index: number) {
  player.queue.value.splice(index, 1);
  if (player.currentIndex.value >= index) {
    player.currentIndex.value = Math.max(0, player.currentIndex.value - 1);
  }
}
</script>

<style scoped>
.queue-drawer-overlay {
  position: fixed;
  inset: 0;
  z-index: 200;
  background: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(4px);
  display: flex;
  justify-content: flex-end;
}

.queue-panel {
  width: 360px;
  height: 100%;
  background: rgba(26, 28, 34, 0.85);
  backdrop-filter: blur(35px) saturate(190%);
  border-left: 1px solid rgba(255, 255, 255, 0.1);
  display: flex;
  flex-direction: column;
  animation: slideLeft 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes slideLeft {
  from { transform: translateX(100%); }
  to { transform: translateX(0); }
}

.queue-header {
  padding: 20px 18px 14px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.queue-title {
  margin: 0;
  font-size: 16px;
  font-weight: 700;
  color: #ffffff;
}

.queue-count {
  font-size: 12px;
  color: #71717a;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.clear-btn {
  background: rgba(255, 255, 255, 0.08);
  border: none;
  border-radius: 6px;
  color: #a1a1aa;
  font-size: 12px;
  padding: 5px 9px;
  display: flex;
  align-items: center;
  gap: 5px;
  cursor: pointer;
  transition: all 0.15s ease;
}

.clear-btn:hover {
  background: rgba(255, 255, 255, 0.15);
  color: #ffffff;
}

.icon-btn {
  background: transparent;
  border: none;
  color: #a1a1aa;
  cursor: pointer;
  padding: 4px;
}

.icon-btn:hover {
  color: #ffffff;
}

.queue-list {
  flex: 1;
  overflow-y: auto;
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.empty-state {
  height: 200px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  color: #71717a;
  font-size: 14px;
}

.queue-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 10px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.15s ease;
}

.queue-item:hover {
  background: rgba(255, 255, 255, 0.08);
}

.queue-item.active {
  background: rgba(255, 255, 255, 0.12);
}

.queue-item.active .item-title {
  color: var(--accent);
  font-weight: 600;
}

.item-artwork {
  position: relative;
  width: 36px;
  height: 36px;
  border-radius: 6px;
  overflow: hidden;
  flex-shrink: 0;
}

.item-artwork img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.playing-indicator {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.55);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 2px;
}

.bar {
  width: 3px;
  background: #ffffff;
  border-radius: 2px;
  animation: bounce 0.6s infinite alternate;
}

.bar-1 { height: 12px; animation-delay: 0.1s; }
.bar-2 { height: 18px; animation-delay: 0.3s; }
.bar-3 { height: 9px;  animation-delay: 0.2s; }

@keyframes bounce {
  from { height: 4px; }
  to { height: 16px; }
}

.item-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.item-title {
  font-size: 13px;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.item-artist {
  font-size: 11px;
  color: #71717a;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.item-duration {
  font-size: 11px;
  color: #71717a;
}

.remove-btn {
  background: transparent;
  border: none;
  color: #71717a;
  padding: 4px;
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.15s ease;
}

.queue-item:hover .remove-btn {
  opacity: 1;
}

.remove-btn:hover {
  color: #ff453a;
}
</style>
