<template>
  <div class="night-bokeh-container" :style="{ '--accent': player.accentColor.value }">
    <!-- Base ambient wash -->
    <div class="base-ambient"></div>

    <!-- Optical Bokeh Spots (Dynamic by Performance Mode) -->
    <template v-if="player.bokehPerformanceMode.value !== 'dark'">
      <div
        v-for="spot in activeSpots"
        :key="spot.id"
        :class="['bokeh-spot', spot.style, `color-${spot.colorType}`]"
        :style="{
          left: `${spot.xRatio * 100}%`,
          top: `${spot.yRatio * 100}%`,
          width: `${spot.diameter}px`,
          height: `${spot.diameter}px`,
          filter: `blur(${spot.blurRadius}px)`,
          opacity: spot.baseOpacity,
          transform: `translate3d(-50%, -50%, 0) translate3d(${isBreathing ? spot.driftX : -spot.driftX}px, ${isBreathing ? spot.driftY : -spot.driftY}px, 0)`,
          transition: 'transform 8s ease-in-out, opacity 5s ease-in-out'
        }"
      ></div>
    </template>

    <!-- Frosted noise grain overlay for tactile texture -->
    <div class="grain-overlay"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { player } from '../stores/player';

interface BokehSpot {
  id: number;
  xRatio: number;
  yRatio: number;
  diameter: number;
  blurRadius: number;
  baseOpacity: number;
  colorType: number; // 0: primary accent, 1: secondary gradient, 2: bright highlight
  style: 'diffuse-cloud' | 'soft-orb' | 'crisp-disc' | 'sparkling-pin';
  driftX: number;
  driftY: number;
}

const isBreathing = ref(false);
let breathingTimer: any = null;

// Exact 19 spots mapped from glMusic's Swift implementation
const allSpots: BokehSpot[] = [
  // 1. Far diffuse clouds (Base ambient background tone)
  { id: 1,  xRatio: 0.82, yRatio: 0.15, diameter: 320, blurRadius: 45, baseOpacity: 0.15, colorType: 0, style: 'diffuse-cloud', driftX: 14, driftY: -12 },
  { id: 2,  xRatio: 0.15, yRatio: 0.20, diameter: 260, blurRadius: 40, baseOpacity: 0.12, colorType: 1, style: 'diffuse-cloud', driftX: -10, driftY: 12 },
  { id: 3,  xRatio: 0.50, yRatio: 0.70, diameter: 290, blurRadius: 45, baseOpacity: 0.11, colorType: 0, style: 'diffuse-cloud', driftX: 12, driftY: 14 },
  { id: 4,  xRatio: 0.88, yRatio: 0.82, diameter: 280, blurRadius: 40, baseOpacity: 0.13, colorType: 1, style: 'diffuse-cloud', driftX: -12, driftY: -10 },

  // 2. Midground soft orbs (Classic bokeh circles)
  { id: 5,  xRatio: 0.70, yRatio: 0.28, diameter: 140, blurRadius: 20, baseOpacity: 0.18, colorType: 1, style: 'soft-orb', driftX: -14, driftY: 10 },
  { id: 6,  xRatio: 0.08, yRatio: 0.48, diameter: 120, blurRadius: 18, baseOpacity: 0.16, colorType: 0, style: 'soft-orb', driftX: 12, driftY: -8 },
  { id: 7,  xRatio: 0.32, yRatio: 0.62, diameter: 130, blurRadius: 18, baseOpacity: 0.15, colorType: 1, style: 'soft-orb', driftX: -10, driftY: 12 },
  { id: 8,  xRatio: 0.78, yRatio: 0.75, diameter: 150, blurRadius: 20, baseOpacity: 0.16, colorType: 0, style: 'soft-orb', driftX: 12, driftY: -12 },

  // 3. Crisp discs (Aperture-rimmed bokeh spots)
  { id: 9,  xRatio: 0.78, yRatio: 0.18, diameter: 80,  blurRadius: 3, baseOpacity: 0.22, colorType: 0, style: 'crisp-disc', driftX: -10, driftY: 8 },
  { id: 10, xRatio: 0.86, yRatio: 0.32, diameter: 60,  blurRadius: 2, baseOpacity: 0.25, colorType: 1, style: 'crisp-disc', driftX: 8, driftY: -10 },
  { id: 11, xRatio: 0.68, yRatio: 0.40, diameter: 96,  blurRadius: 3, baseOpacity: 0.20, colorType: 2, style: 'crisp-disc', driftX: -8, driftY: -8 },
  { id: 12, xRatio: 0.18, yRatio: 0.35, diameter: 70,  blurRadius: 2, baseOpacity: 0.22, colorType: 0, style: 'crisp-disc', driftX: 10, driftY: 8 },
  { id: 13, xRatio: 0.25, yRatio: 0.72, diameter: 76,  blurRadius: 3, baseOpacity: 0.20, colorType: 2, style: 'crisp-disc', driftX: -8, driftY: 10 },
  { id: 14, xRatio: 0.62, yRatio: 0.82, diameter: 88,  blurRadius: 3, baseOpacity: 0.19, colorType: 1, style: 'crisp-disc', driftX: 8, driftY: -10 },
  { id: 15, xRatio: 0.92, yRatio: 0.58, diameter: 54,  blurRadius: 2, baseOpacity: 0.26, colorType: 0, style: 'crisp-disc', driftX: -6, driftY: 6 },

  // 4. Foreground sparkling pins (Gleaming specular highlights)
  { id: 16, xRatio: 0.94, yRatio: 0.18, diameter: 34,  blurRadius: 2, baseOpacity: 0.38, colorType: 2, style: 'sparkling-pin', driftX: 6, driftY: -6 },
  { id: 17, xRatio: 0.64, yRatio: 0.20, diameter: 40,  blurRadius: 3, baseOpacity: 0.32, colorType: 2, style: 'soft-orb', driftX: -8, driftY: 8 },
  { id: 18, xRatio: 0.20, yRatio: 0.82, diameter: 30,  blurRadius: 2, baseOpacity: 0.40, colorType: 2, style: 'sparkling-pin', driftX: 6, driftY: 8 },
  { id: 19, xRatio: 0.45, yRatio: 0.88, diameter: 38,  blurRadius: 3, baseOpacity: 0.30, colorType: 0, style: 'soft-orb', driftX: -6, driftY: -8 },
];

const activeSpots = computed(() => {
  if (player.bokehPerformanceMode.value === 'light') {
    // Only 6 essential spots in lightweight mode for maximum battery & GPU savings
    return [allSpots[0], allSpots[1], allSpots[4], allSpots[5], allSpots[8], allSpots[15]];
  }
  return allSpots;
});

onMounted(() => {
  breathingTimer = setInterval(() => {
    isBreathing.value = !isBreathing.value;
  }, 8000);
});

onUnmounted(() => {
  if (breathingTimer) clearInterval(breathingTimer);
});
</script>

<style scoped>
.night-bokeh-container {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
  z-index: 0;
  background-color: #121316;
  contain: layout paint;
}

.base-ambient {
  position: absolute;
  inset: 0;
  background: radial-gradient(circle at 50% 30%, rgba(30, 32, 40, 0.85) 0%, rgba(14, 15, 18, 0.98) 100%);
}

.bokeh-spot {
  position: absolute;
  border-radius: 50%;
  will-change: transform;
  backface-visibility: hidden;
  transform: translate3d(0, 0, 0);
}

/* Colors based on theme */
.color-0 {
  background: var(--accent);
}

.color-1 {
  background: color-mix(in srgb, var(--accent) 70%, #ff2d55);
}

.color-2 {
  background: color-mix(in srgb, var(--accent) 40%, #ffffff);
}

/* Optical styles */
.diffuse-cloud {
  border-radius: 40% 60% 70% 30% / 40% 50% 60% 50%;
}

.soft-orb {
  box-shadow: 0 0 35px var(--accent);
}

.crisp-disc {
  border: 1.5px solid rgba(255, 255, 255, 0.35);
  box-shadow: inset 0 0 10px rgba(255, 255, 255, 0.2), 0 0 14px var(--accent);
}

.sparkling-pin {
  border: 2px solid rgba(255, 255, 255, 0.7);
  box-shadow: 0 0 14px rgba(255, 255, 255, 0.8), 0 0 20px var(--accent);
}

.grain-overlay {
  position: absolute;
  inset: 0;
  opacity: 0.025;
  background-image: radial-gradient(#fff 1px, transparent 0);
  background-size: 8px 8px;
}
</style>
