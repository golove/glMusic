export interface Artist {
  id: number;
  name: string;
  picUrl?: string;
  musicSize?: number;
  albumSize?: number;
}

export interface Album {
  id: number;
  name: string;
  picUrl: string;
  artist?: Artist;
  publishTime?: number;
  size?: number;
}

export interface Song {
  id: number;
  name: string;
  artists: Artist[];
  artistText: string;
  album: Album;
  duration: number; // in milliseconds
  durationText?: string;
  url?: string;
  level?: string;
  freeTrial?: boolean;
}

export interface Playlist {
  id: number;
  name: string;
  coverImgUrl: string;
  description?: string;
  playCount?: number;
  trackCount?: number;
  creator?: {
    userId: number;
    nickname: string;
    avatarUrl: string;
  };
}

export interface BannerItem {
  imageUrl: string;
  targetId: number;
  targetType: number;
  typeTitle: string;
  url?: string;
}

export interface LyricLine {
  time: number; // seconds
  text: string;
  translation?: string;
}

export type SoundQuality = 'standard' | 'exhigh' | 'lossless' | 'hires';
export type RepeatMode = 'off' | 'all' | 'one';

export interface UserProfile {
  userId: number;
  nickname: string;
  avatarUrl: string;
  vipType?: number;
}
