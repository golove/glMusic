//
//  LyricsView.swift
//  glMusic
//
//  Created by go love on 10/26/26.
//

import SwiftUI

struct LyricsView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager
    @State private var hoveredLineId: UUID?
    @State private var autoScroll = true
    @State private var lastVolume: Double = 0.5
   
    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant(nil)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Blurred Artwork Background (严格贴合窗口大小，防止图片撑大窗口)
            backgroundArtwork
            
            // 主题流光氛围背景 (优雅通透，自适应随主题平滑渐变)
            NightBokehBackground()

            // Main Content: 左侧专辑封面与播放控制 + 右侧滚动歌词 (保持原位布局)
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let availableHeight = geometry.size.height

                // 根据窗口宽度和高度动态计算封面大小
                let coverSize = min(
                    availableWidth * 0.28,
                    max(180, availableHeight * 0.45),
                    320
                )

                HStack(alignment: .top, spacing: 24) {
                    leftArtSection(coverSize: coverSize)

                    rightLyricsSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }

            // 顶部常驻导航与控制栏 (左侧返回，右侧播放设备与音量调节，纯净无胶囊，且100%可点击)
            topBarSection
                .zIndex(100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    // MARK: - Top Bar Section (顶部两端常驻控制栏)

    private var topBarSection: some View {
        HStack {
            topPinnedBar
                .opacity(0.66)
                .padding(.leading, 74)

            Spacer()

            AudioDevicePickerAndVolume
//                .opacity(0.33)
                .padding(.trailing, 24)
        }
        .frame(height: 36)
        .padding(.top, 14)
    }

    // MARK: - Top Pinned Bar (左侧返回按钮)

    private var topPinnedBar: some View {
        @Bindable var player = player
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                player.isShowingLyrics.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(8)
            .foregroundStyle(themeManager.accentColor)
            .background(themeManager.tintColor, in: Circle())
            .contentShape(Circle())
        }
        .padding(.horizontal, 6)
//        .padding(.top,-25)
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
        .help("返回 (Esc)".localized)
    }

    // MARK: - Audio Device & Volume (右侧音频设备选择与音量调节)

    private var AudioDevicePickerAndVolume: some View {
        @Bindable var player = player
        return HStack(spacing: 8) {
            // 选择播放设备 (放到音量调整前面)
            AudioDevicePickerButton(style: .lyrics)

            HStack(spacing: 8) {
                ProgressSlider(
                    value: $player.volume,
                    trackHeight: 6,
                    activeColor: .white,
                    inactiveColor: .white.opacity(0.25)
                )
                .frame(width: 96)

                Button {
                    if player.volume > 0 {
                        lastVolume = player.volume
                        player.volume = 0
                    } else {
                        player.volume = lastVolume > 0 ? lastVolume : 0.5
                    }
                } label: {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(player.volume == 0 ? "取消静音".localized : "静音".localized)
            }
            .frame(width: 130)
        }
   
    }

    private var volumeIcon: String {
        if player.volume == 0    { return "speaker.slash.fill" }
        if player.volume < 0.33  { return "speaker.wave.1.fill" }
        if player.volume < 0.66  { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var backgroundArtwork: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                if let song = player.currentSong {
                    if let localURL = DownloadManager.shared.localCoverURL(for: song.id),
                       let img = NSImage(contentsOf: localURL) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .blur(radius: 65)
                            .scaleEffect(1.15)
                            .opacity(0.48)
                            .drawingGroup()
                    } else if let url = URL(string: song.coverUrl ?? "") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                                    .clipped()
                                    .blur(radius: 65)
                                    .scaleEffect(1.15)
                                    .opacity(0.48)
                                    .drawingGroup()
                            default:
                                Color.clear
                            }
                        }
                    }
                }

                // Apple Music 沉浸式暗角渐变蒙版 (顶部压暗保护顶栏标题与返回按钮，底部压暗保护歌词)
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.25),
                        Color.black.opacity(0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Left Art Section & Controls

    private func leftArtSection(coverSize: CGFloat) -> some View {
        @Bindable var player = player

        return VStack(spacing: 12) {
            if let song = player.currentSong {
                Group {
                    if let localURL = DownloadManager.shared.localCoverURL(for: song.id),
                       let img = NSImage(contentsOf: localURL) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        AsyncImage(url: URL(string: song.coverUrl ?? "")) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white.opacity(0.1))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 44))
                                            .foregroundStyle(.white.opacity(0.4))
                                    )
                            }
                        }
                    }
                }
                .background(Color.clear)
                .frame(width: coverSize+20, height: coverSize+20)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                .padding(.top,-120)

                // 歌曲信息
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(song.name)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()

                        // 选择播放设备 (放到喜欢按钮前面)
//                        AudioDevicePickerButton(style: .lyrics)

                        Button {
                            player.toggleLike(for: song)
                        } label: {
                            Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                                .font(.system(size: 22))
                                .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }

                    ArtistLinksView(
                        artists: song.ar,
                        fallbackText: song.displayArtist,
                        fontSize: 13,
                        weight: .medium,
                        normalColor: .white.opacity(0.8),
                        hoverColor: .white,
                        separatorColor: .white.opacity(0.5)
                    ) { artistId in
                        navigateToArtist(id: artistId)
                    }

                    if !song.displayAlbum.isEmpty {
                        if let albumId = song.al?.id, albumId > 0 {
                            ArtistClickableLabel(
                                name: song.displayAlbum,
                                fontSize: 11,
                                weight: .regular,
                                normalColor: .white.opacity(0.5),
                                hoverColor: .white.opacity(0.9)
                            ) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    player.isShowingLyrics = false
                                }
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    selection = "album_\(albumId)"
                                }
                            }
                        } else {
                            Text(song.displayAlbum)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(width: coverSize + 80, alignment: .leading)
                .padding(.top, 20)

                // 进度条控制
                VStack(spacing: 4) {
                    ProgressSlider(
                        value: $player.progress,
                        trackHeight: 5,
                        activeColor: .white,
                        inactiveColor: .white.opacity(0.25)
                    )

                    HStack {
                        Text(player.currentTimeText)
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(player.remainingTimeText)
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(width: coverSize + 80)
                

                HStack(spacing: (coverSize-90)/4) {
                    Button { player.toggleShuffle() } label: {
                        Image(systemName: "shuffle")
                            
                            .font(.system(size: 18))
                            .foregroundStyle(player.isShuffled ? themeManager.accentColor : .secondary)
                           
                    }
                    .buttonStyle(.plain)
                 

                    Button { player.previous() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.primary)
                           
                    }
                    .buttonStyle(.plain)

                    Button { player.togglePlay() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Button { player.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Button { player.cycleRepeat() } label: {
                        Image(systemName: player.repeatMode.systemImage)
                            .font(.system(size: 18))
                            .foregroundStyle(player.repeatMode.isActive ? themeManager.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
//                .frame(width: coverSize+80)
            }
               
        }
        
        .frame(width: coverSize + 120)
        .frame(maxHeight: .infinity)
        .padding(.bottom, 20)
        .padding(.leading,96 * (320 / coverSize))
//        .background(Color.pink)
//        .frame(width: leftColumnWidth+90,alignment: .trailing)

    }

    // MARK: - Right Lyrics Section

    private var rightLyricsSection: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    if player.isLoadingLyrics {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在加载歌词...".localized)
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.vertical, 40)
                    } else if player.lyrics.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("纯音乐，请欣赏".localized)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(Array(player.lyrics.enumerated()), id: \.element.id) { index, line in
                            let isActive = index == player.currentLyricIndex
                            let isHovered = hoveredLineId == line.id

                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.text)
                                    .font(.system(size: isActive ? 24 : 20, weight: isActive ? .bold : .medium))
                                    .foregroundStyle(
                                        isActive
                                            ? Color.white
                                            : (isHovered ? Color.white.opacity(0.85) : Color.white.opacity(0.35))
                                    )
                                    .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isActive)

                                if let trans = line.translation, !trans.isEmpty {
                                    Text(trans)
                                        .font(.system(size: isActive ? 20 : 18, weight: .medium))
                                        .foregroundStyle(
                                            isActive
                                                ? Color.white.opacity(0.85)
                                                : (isHovered ? Color.white.opacity(0.65) : Color.white.opacity(0.25))
                                        )
                                }
                            }
                            .id(line.id)
                            .contentShape(Rectangle())
                            .onHover { h in hoveredLineId = h ? line.id : nil }
                            .onTapGesture {
                                player.seek(to: line.time)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 48)
            }
            .onChange(of: player.currentLyricIndex) {
                if autoScroll && !player.lyrics.isEmpty && player.currentLyricIndex < player.lyrics.count {
                    let activeId = player.lyrics[player.currentLyricIndex].id
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(activeId, anchor: .center)
                    }
                }
            }
        }
    }
    
    
    private func navigateToArtist(id: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            player.isShowingLyrics = false
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            selection = "artist_\(id)"
        }
    }
}


#Preview("歌词布局测试") {
    let player = LyricsPreviewData.makePlayer()
        
        

    LyricsView()
        .environment(player)
        .environment(ThemeManager.shared)
        .environment(ThemeManager.shared)
        .environment(LanguageManager.shared)
        .frame(width: 1200, height: 760)
}
