import { ref } from 'vue';
import type { Song, LyricLine, SoundQuality, RepeatMode, UserProfile } from '../types/music';
import { api } from '../services/api';

class PlayerStore {
  // Audio instance
  private audio = new Audio();

  // Playback state
  public currentSong = ref<Song | null>(null);
  public isPlaying = ref(false);
  public currentTime = ref(0); // seconds
  public duration = ref(0); // seconds
  public volume = ref(0.7);
  public isMuted = ref(false);
  public soundQuality = ref<SoundQuality>('exhigh');
  public repeatMode = ref<RepeatMode>('off');
  public isShuffled = ref(false);
  public isLoading = ref(false);

  // Queue & History
  public queue = ref<Song[]>([]);
  public currentIndex = ref(-1);
  public history = ref<Song[]>([]);
  public favorites = ref<Song[]>([]);
  public likedSongIds = ref<Set<number>>(new Set());

  // Lyrics
  public lyrics = ref<LyricLine[]>([]);
  public currentLyricIndex = ref(0);
  public isLoadingLyrics = ref(false);

  // UI state
  public isShowingLyrics = ref(false);
  public isShowingQueue = ref(false);
  public isShowingLoginModal = ref(false);
  public currentUser = ref<UserProfile | null>(null);
  public accentColor = ref('#0071e3'); // Apple Music blue/crimson theme

  // Navigation
  public currentRoute = ref('home');
  public currentRouteParam = ref<any>(null);

  constructor() {
    this.setupAudioListeners();
    this.restoreSettings();
  }

  private setupAudioListeners() {
    this.audio.volume = this.volume.value;

    this.audio.addEventListener('timeupdate', () => {
      this.currentTime.value = this.audio.currentTime;
      this.updateCurrentLyric();
    });

    this.audio.addEventListener('durationchange', () => {
      if (!isNaN(this.audio.duration)) {
        this.duration.value = this.audio.duration;
      }
    });

    this.audio.addEventListener('ended', () => {
      this.handleSongEnded();
    });

    this.audio.addEventListener('error', (e) => {
      console.error('Audio playback error', e);
      this.isLoading.value = false;
      this.isPlaying.value = false;
    });

    this.audio.addEventListener('playing', () => {
      this.isPlaying.value = true;
      this.isLoading.value = false;
    });

    this.audio.addEventListener('pause', () => {
      this.isPlaying.value = false;
    });

    this.audio.addEventListener('waiting', () => {
      this.isLoading.value = true;
    });

    this.audio.addEventListener('canplay', () => {
      this.isLoading.value = false;
    });
  }

  private async restoreSettings() {
    try {
      const savedVol = localStorage.getItem('player_volume');
      if (savedVol) {
        this.volume.value = parseFloat(savedVol);
        this.audio.volume = this.volume.value;
      }

      const savedQuality = localStorage.getItem('player_sound_quality') as SoundQuality;
      if (savedQuality) {
        this.soundQuality.value = savedQuality;
      }

      const savedTheme = localStorage.getItem('theme_accent_color');
      if (savedTheme) {
        this.accentColor.value = savedTheme;
      }

      // Restore history & favorites
      const hist = await api.getLocalHistory();
      if (hist && hist.length > 0) {
        this.history.value = hist;
      }

      const favs = await api.getLocalFavorites();
      if (favs && favs.length > 0) {
        this.favorites.value = favs;
        this.likedSongIds.value = new Set(favs.map(s => s.id));
      }

      // Check login status
      const user = await api.getLoginStatus();
      if (user) {
        this.currentUser.value = user;
        const likedIds = await api.getLikelist(user.userId);
        if (likedIds && likedIds.length > 0) {
          likedIds.forEach(id => this.likedSongIds.value.add(id));
        }
      }
    } catch (e) {
      console.warn('Error during player state restoration', e);
    }
  }

  public async play(song: Song, newQueue?: Song[]) {
    this.currentSong.value = song;
    this.isLoading.value = true;

    // Handle queue
    if (newQueue) {
      this.queue.value = [...newQueue];
      this.currentIndex.value = this.queue.value.findIndex(s => s.id === song.id);
    } else {
      const existingIdx = this.queue.value.findIndex(s => s.id === song.id);
      if (existingIdx !== -1) {
        this.currentIndex.value = existingIdx;
      } else {
        this.queue.value.push(song);
        this.currentIndex.value = this.queue.value.length - 1;
      }
    }

    // Record history
    this.addToHistory(song);

    // Fetch lyrics concurrently
    this.fetchLyrics(song.id);

    // Fetch song URL
    try {
      const url = await api.getSongUrl(song.id, this.soundQuality.value);
      if (url) {
        this.audio.src = url;
        await this.audio.play();
        this.isPlaying.value = true;
      } else {
        console.warn('No playable URL found for song', song.name);
      }
    } catch (err) {
      console.error('Failed to play song', err);
    } finally {
      this.isLoading.value = false;
    }
  }

  public togglePlay() {
    if (!this.currentSong.value) {
      if (this.queue.value.length > 0) {
        this.play(this.queue.value[0]);
      }
      return;
    }

    if (this.isPlaying.value) {
      this.audio.pause();
    } else {
      this.audio.play().catch(e => console.error('Play error', e));
    }
  }

  public seek(seconds: number) {
    if (isNaN(seconds) || seconds < 0) return;
    const clamped = Math.min(seconds, this.duration.value);
    this.audio.currentTime = clamped;
    this.currentTime.value = clamped;
  }

  public seekByProgress(ratio: number) {
    this.seek(ratio * this.duration.value);
  }

  public setVolume(vol: number) {
    const clamped = Math.max(0, Math.min(1, vol));
    this.volume.value = clamped;
    this.audio.volume = clamped;
    this.isMuted.value = clamped === 0;
    localStorage.setItem('player_volume', clamped.toString());
  }

  public toggleMute() {
    if (this.isMuted.value) {
      this.audio.volume = this.volume.value || 0.5;
      this.isMuted.value = false;
    } else {
      this.audio.volume = 0;
      this.isMuted.value = true;
    }
  }

  public setQuality(quality: SoundQuality) {
    this.soundQuality.value = quality;
    localStorage.setItem('player_sound_quality', quality);
    if (this.currentSong.value && this.isPlaying.value) {
      const curTime = this.currentTime.value;
      this.play(this.currentSong.value).then(() => {
        this.seek(curTime);
      });
    }
  }

  public setAccentColor(color: string) {
    this.accentColor.value = color;
    localStorage.setItem('theme_accent_color', color);
  }

  public next() {
    if (this.queue.value.length === 0) return;

    if (this.isShuffled.value) {
      const randIdx = Math.floor(Math.random() * this.queue.value.length);
      this.play(this.queue.value[randIdx]);
      return;
    }

    let nextIdx = this.currentIndex.value + 1;
    if (nextIdx >= this.queue.value.length) {
      nextIdx = 0;
    }
    this.play(this.queue.value[nextIdx]);
  }

  public previous() {
    if (this.queue.value.length === 0) return;

    if (this.currentTime.value > 3) {
      this.seek(0);
      return;
    }

    let prevIdx = this.currentIndex.value - 1;
    if (prevIdx < 0) {
      prevIdx = this.queue.value.length - 1;
    }
    this.play(this.queue.value[prevIdx]);
  }

  private handleSongEnded() {
    if (this.repeatMode.value === 'one') {
      this.seek(0);
      this.audio.play();
    } else if (this.repeatMode.value === 'all' || this.queue.value.length > 1) {
      this.next();
    } else {
      this.isPlaying.value = false;
    }
  }

  public toggleRepeatMode() {
    if (this.repeatMode.value === 'off') {
      this.repeatMode.value = 'all';
    } else if (this.repeatMode.value === 'all') {
      this.repeatMode.value = 'one';
    } else {
      this.repeatMode.value = 'off';
    }
  }

  public toggleShuffle() {
    this.isShuffled.value = !this.isShuffled.value;
  }

  public async toggleLike(song: Song) {
    const isLiked = this.likedSongIds.value.has(song.id);
    const newLiked = !isLiked;

    if (newLiked) {
      this.likedSongIds.value.add(song.id);
      if (!this.favorites.value.some(s => s.id === song.id)) {
        this.favorites.value.unshift(song);
      }
    } else {
      this.likedSongIds.value.delete(song.id);
      this.favorites.value = this.favorites.value.filter(s => s.id !== song.id);
    }

    // Persist local favorites
    await api.saveLocalFavorites(this.favorites.value);

    // Sync with NetEase Cloud if logged in
    if (this.currentUser.value) {
      try {
        await api.like(song.id, newLiked);
      } catch (e) {
        console.warn('Failed to sync like with NetEase', e);
      }
    }
  }

  private async addToHistory(song: Song) {
    this.history.value = [song, ...this.history.value.filter(s => s.id !== song.id)].slice(0, 200);
    await api.saveLocalHistory(this.history.value);
  }

  public async fetchLyrics(id: number) {
    this.isLoadingLyrics.value = true;
    try {
      const resp = await api.getLyric(id);
      this.lyrics.value = this.parseLyrics(resp.lyric, resp.tlyric);
      this.currentLyricIndex.value = 0;
    } catch (e) {
      console.warn('Failed to fetch lyrics', e);
      this.lyrics.value = [];
    } finally {
      this.isLoadingLyrics.value = false;
    }
  }

  private parseLyrics(rawLrc: string, rawTrans?: string): LyricLine[] {
    if (!rawLrc) return [];
    const timeExp = /\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\]/g;
    const lines: LyricLine[] = [];

    // Parse translations if present
    const transMap = new Map<number, string>();
    if (rawTrans) {
      for (const line of rawTrans.split('\n')) {
        let match;
        timeExp.lastIndex = 0;
        while ((match = timeExp.exec(line)) !== null) {
          const min = parseInt(match[1], 10);
          const sec = parseInt(match[2], 10);
          const ms = match[3] ? parseInt(match[3].padEnd(3, '0').slice(0, 3), 10) : 0;
          const time = Math.round((min * 60 + sec + ms / 1000) * 10) / 10;
          const text = line.replace(/\[\d{2}:\d{2}(?:\.\d{2,3})?\]/g, '').trim();
          if (text) {
            transMap.set(time, text);
          }
        }
      }
    }

    // Parse main lyrics
    for (const line of rawLrc.split('\n')) {
      let match;
      timeExp.lastIndex = 0;
      while ((match = timeExp.exec(line)) !== null) {
        const min = parseInt(match[1], 10);
        const sec = parseInt(match[2], 10);
        const ms = match[3] ? parseInt(match[3].padEnd(3, '0').slice(0, 3), 10) : 0;
        const time = min * 60 + sec + ms / 1000;
        const text = line.replace(/\[\d{2}:\d{2}(?:\.\d{2,3})?\]/g, '').trim();
        if (text) {
          const roundedKey = Math.round(time * 10) / 10;
          lines.push({
            time,
            text,
            translation: transMap.get(roundedKey)
          });
        }
      }
    }

    return lines.sort((a, b) => a.time - b.time);
  }

  private updateCurrentLyric() {
    if (this.lyrics.value.length === 0) return;
    const curTime = this.currentTime.value;
    let activeIdx = 0;

    for (let i = 0; i < this.lyrics.value.length; i++) {
      if (curTime >= this.lyrics.value[i].time) {
        activeIdx = i;
      } else {
        break;
      }
    }
    this.currentLyricIndex.value = activeIdx;
  }

  public navigate(route: string, param?: any) {
    this.currentRoute.value = route;
    this.currentRouteParam.value = param;
  }
}

export const player = new PlayerStore();
