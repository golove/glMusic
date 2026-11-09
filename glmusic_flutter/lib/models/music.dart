class Artist {
  final int id;
  final String name;
  final String picUrl;

  const Artist({
    required this.id,
    required this.name,
    this.picUrl = '',
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '未知歌手',
      picUrl: (json['picUrl'] ?? json['img1v1Url'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'picUrl': picUrl,
  };
}

class Album {
  final int id;
  final String name;
  final String picUrl;
  final Artist? artist;
  final int? publishTime;

  const Album({
    required this.id,
    required this.name,
    this.picUrl = '',
    this.artist,
    this.publishTime,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '未知专辑',
      picUrl: (json['picUrl'] ?? '') as String,
      artist: json['artist'] != null ? Artist.fromJson(json['artist'] as Map<String, dynamic>) : null,
      publishTime: json['publishTime'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'picUrl': picUrl,
    'publishTime': publishTime,
  };
}

class Song {
  final int id;
  final String name;
  final List<Artist> artists;
  final String artistText;
  final Album album;
  final int duration; // in milliseconds
  final String durationText;
  final String? url;

  const Song({
    required this.id,
    required this.name,
    required this.artists,
    required this.artistText,
    required this.album,
    required this.duration,
    required this.durationText,
    this.url,
  });

  factory Song.fromRaw(Map<String, dynamic> raw) {
    final rawArtists = (raw['ar'] ?? raw['artists'] ?? []) as List<dynamic>;
    final artists = rawArtists.map((a) => Artist.fromJson(a as Map<String, dynamic>)).toList();
    final artistText = artists.isNotEmpty
        ? artists.map((a) => a.name).join(' / ')
        : '未知歌手';

    final rawAlbum = (raw['al'] ?? raw['album'] ?? {}) as Map<String, dynamic>;
    final album = Album.fromJson(rawAlbum);

    final duration = (raw['dt'] ?? raw['duration'] ?? 0) as int;
    final durSec = duration ~/ 1000;
    final min = durSec ~/ 60;
    final sec = durSec % 60;
    final durationText = '$min:${sec < 10 ? '0' : ''}$sec';

    return Song(
      id: raw['id'] as int? ?? 0,
      name: (raw['name'] ?? '未知歌曲') as String,
      artists: artists,
      artistText: artistText,
      album: album,
      duration: duration,
      durationText: durationText,
      url: raw['url'] as String?,
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    final artists = ((json['artists'] ?? []) as List<dynamic>)
        .map((a) => Artist.fromJson(a as Map<String, dynamic>))
        .toList();
    return Song(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '未知歌曲',
      artists: artists,
      artistText: json['artistText'] as String? ?? '',
      album: Album.fromJson((json['album'] ?? {}) as Map<String, dynamic>),
      duration: json['duration'] as int? ?? 0,
      durationText: json['durationText'] as String? ?? '0:00',
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'artists': artists.map((a) => a.toJson()).toList(),
    'artistText': artistText,
    'album': album.toJson(),
    'duration': duration,
    'durationText': durationText,
    'url': url,
  };
}

class Playlist {
  final int id;
  final String name;
  final String coverImgUrl;
  final String? description;
  final int? playCount;
  final int? trackCount;
  final Map<String, dynamic>? creator;

  const Playlist({
    required this.id,
    required this.name,
    required this.coverImgUrl,
    this.description,
    this.playCount,
    this.trackCount,
    this.creator,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '精选歌单',
      coverImgUrl: (json['coverImgUrl'] ?? json['picUrl'] ?? '') as String,
      description: json['description'] as String?,
      playCount: json['playCount'] as int?,
      trackCount: json['trackCount'] as int?,
      creator: json['creator'] as Map<String, dynamic>?,
    );
  }
}

class BannerItem {
  final String imageUrl;
  final int? targetId;
  final int? targetType;
  final String typeTitle;
  final String? url;

  const BannerItem({
    required this.imageUrl,
    this.targetId,
    this.targetType,
    required this.typeTitle,
    this.url,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      imageUrl: (json['pic'] ?? json['imageUrl'] ?? '') as String,
      targetId: json['targetId'] as int?,
      targetType: json['targetType'] as int?,
      typeTitle: json['typeTitle'] as String? ?? '推荐',
      url: json['url'] as String?,
    );
  }
}

class LyricLine {
  final double time; // seconds
  final String text;
  final String? translation;

  const LyricLine({
    required this.time,
    required this.text,
    this.translation,
  });
}

enum SoundQuality {
  standard('standard', '标准'),
  exhigh('exhigh', '极高'),
  lossless('lossless', '无损'),
  hires('hires', 'Hi-Res');

  final String code;
  final String label;
  const SoundQuality(this.code, this.label);
}

enum PlayRepeatMode {
  off('顺序播放'),
  all('列表循环'),
  one('单曲循环');

  final String label;
  const PlayRepeatMode(this.label);
}

class UserProfile {
  final int userId;
  final String nickname;
  final String avatarUrl;

  const UserProfile({
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as int? ?? 0,
      nickname: json['nickname'] as String? ?? '网易云音乐用户',
      avatarUrl: json['avatarUrl'] as String? ?? '',
    );
  }
}
