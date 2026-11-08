<template>
  <div v-if="player.isShowingLoginModal.value" class="login-modal-overlay" @click.self="close">
    <div class="login-card" :style="{ '--accent': player.accentColor.value }">
      <div class="modal-header">
        <h3 class="modal-title">网易云音乐登录</h3>
        <button class="close-btn" @click="close">
          <X :size="18" />
        </button>
      </div>

      <div class="modal-body">
        <p class="instruction-text">请打开网易云音乐手机客户端扫一扫登录</p>

        <div class="qr-container">
          <div v-if="isLoading" class="qr-placeholder">
            <Loader2 class="spin-icon" :size="32" />
            <span>生成二维码中...</span>
          </div>

          <div v-else class="qr-box">
            <img v-if="qrImage" :src="qrImage" alt="Login QR Code" class="qr-img" />
            <div v-if="qrExpired" class="expired-overlay" @click="initQR">
              <RefreshCw :size="24" />
              <span>二维码已失效，点击刷新</span>
            </div>
          </div>
        </div>

        <div class="status-msg">
          <span :class="statusClass">{{ statusText }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onUnmounted, watch } from 'vue';
import { X, RefreshCw, Loader2 } from 'lucide-vue-next';
import { player } from '../stores/player';
import { api } from '../services/api';

const qrKey = ref('');
const qrImage = ref('');
const isLoading = ref(true);
const qrExpired = ref(false);
const statusText = ref('等待扫码...');
const statusClass = ref('status-waiting');
let pollTimer: any = null;

async function initQR() {
  isLoading.value = true;
  qrExpired.value = false;
  statusText.value = '等待扫码...';
  statusClass.value = 'status-waiting';

  try {
    const key = await api.getLoginQrKey();
    qrKey.value = key;
    if (key) {
      const img = await api.createLoginQr(key);
      qrImage.value = img;
      startPolling();
    }
  } catch (e) {
    statusText.value = '生成二维码失败，请检查网络';
  } finally {
    isLoading.value = false;
  }
}

function startPolling() {
  stopPolling();
  pollTimer = setInterval(async () => {
    if (!qrKey.value) return;
    try {
      const checkRes = await api.checkLoginQr(qrKey.value);
      const code = checkRes.code;

      if (code === 800) {
        // Expired
        qrExpired.value = true;
        statusText.value = '二维码已失效';
        statusClass.value = 'status-expired';
        stopPolling();
      } else if (code === 801) {
        statusText.value = '等待扫码中...';
        statusClass.value = 'status-waiting';
      } else if (code === 802) {
        statusText.value = '扫码成功，请在手机上点击确认授权';
        statusClass.value = 'status-scanned';
      } else if (code === 803) {
        statusText.value = '登录成功！';
        statusClass.value = 'status-success';
        stopPolling();

        // Refresh user profile
        const user = await api.getLoginStatus();
        if (user) {
          player.currentUser.value = user;
          const liked = await api.getLikelist(user.userId);
          liked.forEach(id => player.likedSongIds.value.add(id));
        }

        setTimeout(() => {
          close();
        }, 1200);
      }
    } catch (e) {
      console.error('Polling error', e);
    }
  }, 2500);
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

function close() {
  stopPolling();
  player.isShowingLoginModal.value = false;
}

watch(
  () => player.isShowingLoginModal.value,
  (show) => {
    if (show) {
      initQR();
    } else {
      stopPolling();
    }
  }
);

onUnmounted(() => {
  stopPolling();
});
</script>

<style scoped>
.login-modal-overlay {
  position: fixed;
  inset: 0;
  z-index: 1000;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(8px);
  display: flex;
  align-items: center;
  justify-content: center;
}

.login-card {
  width: 360px;
  background: rgba(28, 30, 36, 0.95);
  backdrop-filter: blur(30px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 20px 48px rgba(0, 0, 0, 0.6);
  display: flex;
  flex-direction: column;
  gap: 16px;
  animation: zoomIn 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes zoomIn {
  from { transform: scale(0.92); opacity: 0; }
  to { transform: scale(1); opacity: 1; }
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  margin: 0;
  font-size: 17px;
  font-weight: 700;
  color: #ffffff;
}

.close-btn {
  background: transparent;
  border: none;
  color: #a1a1aa;
  cursor: pointer;
}

.close-btn:hover {
  color: #ffffff;
}

.modal-body {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 18px;
}

.instruction-text {
  font-size: 13px;
  color: #94949b;
  margin: 0;
  text-align: center;
}

.qr-container {
  width: 200px;
  height: 200px;
  background: #ffffff;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
}

.qr-box {
  position: relative;
  width: 100%;
  height: 100%;
}

.qr-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.qr-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  color: #52525b;
  font-size: 13px;
}

.expired-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.85);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: #ffffff;
  font-size: 12px;
  cursor: pointer;
  text-align: center;
  padding: 12px;
}

.status-msg {
  font-size: 13px;
  font-weight: 500;
}

.status-waiting { color: #a1a1aa; }
.status-scanned { color: #30d158; }
.status-expired { color: #ff453a; }
.status-success { color: #30d158; font-weight: 600; }

.spin-icon {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
