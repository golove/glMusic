import { invoke } from '@tauri-apps/api/core';
import type { Song, Playlist, BannerItem, Artist, Album, UserProfile } from '../types/music';

// Helper to convert NCM API song objects into our standardized Song struct
export function formatSong(raw: any): Song {
  const artists: Artist[] = (raw.ar || raw.artists || []).map((a: any) => ({
    id: a.id,
    name: a.name || '未知歌手',
    picUrl: a.picUrl || a.img1v1Url
  }));

  const artistText = artists.map(a => a.name).join(' / ') || '未知歌手';

  const albumObj = raw.al || raw.album || {};
  const album: Album = {
    id: albumObj.id || 0,
    name: albumObj.name || '未知专辑',
    picUrl: albumObj.picUrl || (albumObj.artist && albumObj.artist.picUrl) || ''
  };

  const duration = raw.dt || raw.duration || 0;
  const durationSec = Math.floor(duration / 1000);
  const min = Math.floor(durationSec / 60);
  const sec = durationSec % 60;
  const durationText = `${min}:${sec < 10 ? '0' : ''}${sec}`;

  return {
    id: raw.id,
    name: raw.name || '未知歌曲',
    artists,
    artistText,
    album,
    duration,
    durationText
  };
}

export const api = {
  // Search
  async search(keywords: string, type = '1', limit = 30, offset = 0): Promise<Song[]> {
    const res: any = await invoke('ncm_search', { keywords, stype: type, limit, offset });
    const songs = res?.result?.songs || [];
    return songs.map(formatSong);
  },

  async searchHot(): Promise<string[]> {
    const res: any = await invoke('ncm_search_hot');
    const list = res?.data || [];
    return list.map((item: any) => item.searchWord).filter(Boolean);
  },

  // Songs & Audio
  async getSongDetail(ids: number[]): Promise<Song[]> {
    if (!ids.length) return [];
    const res: any = await invoke('ncm_song_detail', { ids: ids.join(',') });
    const songs = res?.songs || [];
    return songs.map(formatSong);
  },

  async getSongUrl(id: number, level = 'exhigh'): Promise<string | null> {
    const res: any = await invoke('ncm_song_url', { id, level });
    const dataList = res?.data || [];
    if (dataList.length > 0 && dataList[0].url) {
      return dataList[0].url;
    }
    return null;
  },

  async getLyric(id: number): Promise<{ lyric: string; tlyric?: string }> {
    const res: any = await invoke('ncm_lyric', { id });
    return {
      lyric: res?.lrc?.lyric || '',
      tlyric: res?.tlyric?.lyric || ''
    };
  },

  // Recommendations & Home
  async getBanners(): Promise<BannerItem[]> {
    const res: any = await invoke('ncm_banner');
    const banners = res?.banners || [];
    return banners.map((b: any) => ({
      imageUrl: b.pic || b.imageUrl,
      targetId: b.targetId,
      targetType: b.targetType,
      typeTitle: b.typeTitle,
      url: b.url
    }));
  },

  async getPersonalizedPlaylists(limit = 12): Promise<Playlist[]> {
    const res: any = await invoke('ncm_personalized', { limit });
    const list = res?.result || [];
    return list.map((item: any) => ({
      id: item.id,
      name: item.name,
      coverImgUrl: item.picUrl,
      playCount: item.playCount,
      trackCount: item.trackCount
    }));
  },

  async getPersonalizedNewSongs(limit = 12): Promise<Song[]> {
    const res: any = await invoke('ncm_personalized_newsong', { limit });
    const list = res?.result || [];
    return list.map((item: any) => {
      const songData = item.song || item;
      return formatSong(songData);
    });
  },

  // Playlists
  async getPlaylistDetail(id: number): Promise<{ playlist: Playlist; tracks: Song[] }> {
    const res: any = await invoke('ncm_playlist_detail', { id });
    const pl = res?.playlist || {};
    const playlist: Playlist = {
      id: pl.id,
      name: pl.name,
      coverImgUrl: pl.coverImgUrl,
      description: pl.description,
      playCount: pl.playCount,
      trackCount: pl.trackCount,
      creator: pl.creator ? {
        userId: pl.creator.userId,
        nickname: pl.creator.nickname,
        avatarUrl: pl.creator.avatarUrl
      } : undefined
    };

    const tracks = (pl.tracks || []).map(formatSong);
    return { playlist, tracks };
  },

  async getPlaylistTracks(id: number, limit = 50, offset = 0): Promise<Song[]> {
    const res: any = await invoke('ncm_playlist_tracks', { id, limit, offset });
    const songs = res?.songs || [];
    return songs.map(formatSong);
  },

  async getTopPlaylists(cat = '全部', limit = 40, offset = 0): Promise<Playlist[]> {
    const res: any = await invoke('ncm_top_playlist', { cat, limit, offset });
    const list = res?.playlists || [];
    return list.map((item: any) => ({
      id: item.id,
      name: item.name,
      coverImgUrl: item.coverImgUrl,
      playCount: item.playCount,
      trackCount: item.trackCount
    }));
  },

  async getToplist(): Promise<Playlist[]> {
    const res: any = await invoke('ncm_toplist');
    const list = res?.list || [];
    return list.map((item: any) => ({
      id: item.id,
      name: item.name,
      coverImgUrl: item.coverImgUrl,
      description: item.description,
      playCount: item.playCount,
      trackCount: item.trackCount
    }));
  },

  async getRecommendSongs(): Promise<Song[]> {
    const res: any = await invoke('ncm_recommend_songs');
    const songs = res?.data?.dailySongs || res?.recommend || [];
    return songs.map(formatSong);
  },

  // Artists
  async getTopArtists(limit = 30): Promise<Artist[]> {
    const res: any = await invoke('ncm_top_artists', { limit });
    const list = res?.artists || [];
    return list.map((a: any) => ({
      id: a.id,
      name: a.name,
      picUrl: a.picUrl || a.img1v1Url,
      musicSize: a.musicSize,
      albumSize: a.albumSize
    }));
  },

  async getArtistDetail(id: number): Promise<{ artist: Artist; hotSongs: Song[] }> {
    const res: any = await invoke('ncm_artist_detail', { id });
    const a = res?.artist || {};
    const artist: Artist = {
      id: a.id,
      name: a.name,
      picUrl: a.picUrl || a.img1v1Url,
      musicSize: a.musicSize,
      albumSize: a.albumSize
    };
    const hotSongs = (res?.hotSongs || []).map(formatSong);
    return { artist, hotSongs };
  },

  async getArtistAlbums(id: number, limit = 30): Promise<Album[]> {
    const res: any = await invoke('ncm_artist_album', { id, limit });
    const list = res?.hotAlbums || [];
    return list.map((alb: any) => ({
      id: alb.id,
      name: alb.name,
      picUrl: alb.picUrl,
      publishTime: alb.publishTime,
      size: alb.size
    }));
  },

  // Albums
  async getAlbum(id: number): Promise<{ album: Album; songs: Song[] }> {
    const res: any = await invoke('ncm_album', { id });
    const a = res?.album || {};
    const album: Album = {
      id: a.id,
      name: a.name,
      picUrl: a.picUrl,
      artist: a.artist ? { id: a.artist.id, name: a.artist.name } : undefined,
      publishTime: a.publishTime,
      size: a.size
    };
    const songs = (res?.songs || []).map(formatSong);
    return { album, songs };
  },

  async getNewAlbums(limit = 30): Promise<Album[]> {
    const res: any = await invoke('ncm_album_new', { limit });
    const list = res?.albums || [];
    return list.map((a: any) => ({
      id: a.id,
      name: a.name,
      picUrl: a.picUrl,
      artist: a.artist ? { id: a.artist.id, name: a.artist.name } : undefined,
      publishTime: a.publishTime,
      size: a.size
    }));
  },

  // DJ Radios
  async getDjBanners(): Promise<any[]> {
    const res: any = await invoke('ncm_dj_banner');
    return res?.data || [];
  },

  async getDjRadios(): Promise<any[]> {
    const res: any = await invoke('ncm_dj_recommend');
    return res?.djRadios || [];
  },

  async getDjCategories(): Promise<any[]> {
    const res: any = await invoke('ncm_dj_catelist');
    return res?.categories || [];
  },

  async getDjRadiosByCategory(cateId: number): Promise<any[]> {
    const res: any = await invoke('ncm_dj_recommend_type', { cateId });
    return res?.djRadios || [];
  },

  async getDjDetail(rid: number): Promise<any> {
    const res: any = await invoke('ncm_dj_detail', { rid });
    return res?.data || null;
  },

  async getDjPrograms(rid: number, limit = 30, offset = 0): Promise<Song[]> {
    const res: any = await invoke('ncm_dj_program', { rid, limit, offset });
    const programs = res?.programs || [];
    return programs.map((p: any) => {
      const mainSong = p.mainSong || {};
      return {
        id: mainSong.id || p.id,
        name: p.name || mainSong.name,
        artists: [{ id: p.dj?.userId || 0, name: p.dj?.nickname || '电台主持' }],
        artistText: p.dj?.nickname || '电台主持',
        album: {
          id: p.radio?.id || 0,
          name: p.radio?.name || '电台节目',
          picUrl: p.coverUrl || mainSong.album?.picUrl || ''
        },
        duration: mainSong.duration || p.duration || 0,
        durationText: ''
      };
    });
  },

  // Login & User
  async getLoginQrKey(): Promise<string> {
    const res: any = await invoke('ncm_login_qr_key');
    return res?.data?.unikey || res?.unikey || '';
  },

  async createLoginQr(key: string): Promise<string> {
    const res: any = await invoke('ncm_login_qr_create', { key });
    return res?.data?.qrimg || res?.qrimg || '';
  },

  async checkLoginQr(key: string): Promise<{ code: number; message: string }> {
    const res: any = await invoke('ncm_login_qr_check', { key });
    return {
      code: res?.code || 0,
      message: res?.message || ''
    };
  },

  async getLoginStatus(): Promise<UserProfile | null> {
    const res: any = await invoke('ncm_login_status');
    const profile = res?.data?.profile || res?.profile;
    if (profile && profile.userId) {
      return {
        userId: profile.userId,
        nickname: profile.nickname,
        avatarUrl: profile.avatarUrl,
        vipType: profile.vipType
      };
    }
    return null;
  },

  async logout(): Promise<void> {
    await invoke('ncm_logout');
  },

  async like(id: number, like = true): Promise<boolean> {
    const res: any = await invoke('ncm_like', { id, like });
    return res?.code === 200;
  },

  async getLikelist(uid: number): Promise<number[]> {
    const res: any = await invoke('ncm_likelist', { uid });
    return res?.ids || [];
  },

  async getUserPlaylists(uid: number, limit = 50, offset = 0): Promise<Playlist[]> {
    const res: any = await invoke('ncm_user_playlist', { uid, limit, offset });
    const list = res?.playlist || [];
    return list.map((item: any) => ({
      id: item.id,
      name: item.name,
      coverImgUrl: item.coverImgUrl,
      playCount: item.playCount,
      trackCount: item.trackCount
    }));
  },

  // Local storage
  async getLocalHistory(): Promise<Song[]> {
    const res: any = await invoke('get_local_history');
    return Array.isArray(res) ? res : [];
  },

  async saveLocalHistory(data: Song[]): Promise<void> {
    await invoke('save_local_history', { data });
  },

  async getLocalFavorites(): Promise<Song[]> {
    const res: any = await invoke('get_local_favorites');
    return Array.isArray(res) ? res : [];
  },

  async saveLocalFavorites(data: Song[]): Promise<void> {
    await invoke('save_local_favorites', { data });
  }
};
