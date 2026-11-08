<template>
  <div class="view-container">
    <div class="header-section">
      <h2 class="view-title">广播与播客</h2>
      <p class="view-subtitle">听见有声世界 · 音乐故事与声音电台</p>

      <!-- Category Filter Pills -->
      <div v-if="categories.length > 0" class="categories-row">
        <button
          :class="['cat-pill', { active: currentCatId === 0 }]"
          @click="selectCategory(0)"
        >
          热门推荐
        </button>
        <button
          v-for="cat in categories"
          :key="cat.id"
          :class="['cat-pill', { active: currentCatId === cat.id }]"
          @click="selectCategory(cat.id)"
        >
          {{ cat.name }}
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="loading-state">
      <Loader2 class="spin-icon" :size="32" />
      <span>正在加载电台...</span>
    </div>

    <!-- Radios Grid -->
    <div v-else class="radios-grid">
      <div
        v-for="radio in radios"
        :key="radio.id"
        class="radio-card"
        @click="openRadio(radio)"
      >
        <div class="cover-box">
          <img :src="radio.picUrl" class="cover-img" alt="" loading="lazy" />
          <div class="play-overlay">
            <Radio :size="24" color="#fff" />
          </div>
          <span class="category-tag">{{ radio.category || '电台' }}</span>
        </div>
        <div class="radio-title" :title="radio.name">{{ radio.name }}</div>
        <div class="radio-rcmd">{{ radio.rcmdtext || radio.desc || '精彩播客节目' }}</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Radio, Loader2 } from 'lucide-vue-next';
import { api } from '../services/api';
import { player } from '../stores/player';

const categories = ref<any[]>([]);
const radios = ref<any[]>([]);
const currentCatId = ref(0);
const isLoading = ref(true);

onMounted(async () => {
  try {
    const [cats, r] = await Promise.all([
      api.getDjCategories(),
      api.getDjRadios()
    ]);
    categories.value = cats;
    radios.value = r;
  } catch (e) {
    console.error('Radio load error', e);
  } finally {
    isLoading.value = false;
  }
});

async function selectCategory(cateId: number) {
  currentCatId.value = cateId;
  isLoading.value = true;
  try {
    if (cateId === 0) {
      radios.value = await api.getDjRadios();
    } else {
      radios.value = await api.getDjRadiosByCategory(cateId);
    }
  } catch (e) {
    console.error('Category error', e);
  } finally {
    isLoading.value = false;
  }
}

async function openRadio(radio: any) {
  try {
    const programs = await api.getDjPrograms(radio.id, 50);
    if (programs.length > 0) {
      player.play(programs[0], programs);
    }
  } catch (e) {
    console.error('Play radio error', e);
  }
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
  gap: 14px;
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

.categories-row {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 4px;
  scrollbar-width: none;
}

.cat-pill {
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: rgba(255, 255, 255, 0.05);
  border-radius: 16px;
  color: #a1a1aa;
  font-size: 13px;
  padding: 5px 14px;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.15s ease;
}

.cat-pill:hover {
  background: rgba(255, 255, 255, 0.12);
  color: #ffffff;
}

.cat-pill.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #ffffff;
  font-weight: 600;
}

.loading-state {
  height: 300px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  color: #71717a;
}

.radios-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 22px;
}

.radio-card {
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
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.4);
  background: rgba(255, 255, 255, 0.05);
}

.cover-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.25s ease;
}

.radio-card:hover .cover-img {
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

.radio-card:hover .play-overlay {
  opacity: 1;
}

.category-tag {
  position: absolute;
  top: 8px;
  left: 8px;
  background: rgba(0, 0, 0, 0.65);
  backdrop-filter: blur(6px);
  padding: 2px 7px;
  border-radius: 8px;
  font-size: 10px;
  color: #ffffff;
}

.radio-title {
  font-size: 13.5px;
  font-weight: 600;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.radio-rcmd {
  font-size: 11.5px;
  color: #71717a;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.spin-icon {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
