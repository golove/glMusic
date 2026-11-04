//
//  LyricsView.swift
//  glMusic
//
//  Created by go love on 10/26/26.
//

import SwiftUI

struct LyricsView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var hoveredLineId: UUID?
    @State private var autoScroll = true
   

    // 统一左侧区域宽度 (封面、信息、进度条、播放按钮保持一致)
//    private let leftColumnWidth: CGFloat = 250

    var body: some View {
        ZStack{
            // Blurred Artwork Background (使用 GeometryReader
          
            
            // 严格贴合窗口大小，防止图片撑大窗口)
            backgroundArtwork
            
            // 主题流光氛围背景 (优雅通透，自适应随主题平滑渐变)
            NightBokehBackground()

            // Main Content
            VStack(spacing: 0) {
                
              
//                   

                // Middle: Left Album Art & Controls + Right Scrolling Lyrics
                // 下方：左侧专辑区域 + 右侧歌词区域
                   
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
                            .frame(width: coverSize + 80)
                            .padding(.leading,availableWidth*0.096)

                        rightLyricsSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.horizontal, 40)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    // 顶部常驻固定导航栏 (不随下方列表滚动)
                   


                            HStack {
                                topPinnedBar
                                    .padding(.top,-90)
                                Spacer()
                            }
                        }
                    
                    .padding(.top,60)
                        .padding(.horizontal, 74)
                

                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(
            minWidth: 960,maxWidth: .infinity,
            minHeight: 620, maxHeight: .infinity
        )
    }

    // MARK: - Background Artwork

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
                .frame(width: coverSize, height: coverSize)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                .padding(.top,-90)

                // 歌曲信息
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(song.name)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            player.toggleLike(for: song)
                        } label: {
                            Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                                .font(.system(size: 22))
                                .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(song.displayArtist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)

                    if !song.displayAlbum.isEmpty {
                        Text(song.displayAlbum)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .frame(width: coverSize + 80, alignment: .leading)
                .padding(.top, 30)

                // 进度条控制
                VStack(spacing: 4) {
                    ProgressSlider(value: $player.progress, trackHeight: 6)

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
                .frame(width: coverSize+80)
            }
               
        }
        
        .frame(width: coverSize + 80)
        .frame(maxHeight: .infinity)
        .padding(.bottom, 20)
        .padding(.horizontal,20)
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
                            Text("正在加载歌词...")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.vertical, 40)
                    } else if player.lyrics.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("纯音乐，请欣赏")
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
                                    .font(.system(size: isActive ? 32 : 28, weight: isActive ? .bold : .medium))
                                    .foregroundStyle(
                                        isActive
                                            ? Color.white
                                            : (isHovered ? Color.white.opacity(0.85) : Color.white.opacity(0.35))
                                    )
                                    .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isActive)

                                if let trans = line.translation, !trans.isEmpty {
                                    Text(trans)
                                        .font(.system(size: isActive ? 13 : 11, weight: .medium))
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
    
    
    // MARK: - Top Pinned Bar
    private var topPinnedBar: some View {
        @Bindable var player = player
          return Button{
                player.isShowingLyrics.toggle()
            }label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
   
                }
                .padding(8)
                .foregroundStyle(themeManager.accentColor)
                .background(themeManager.tintColor, in: Circle())
                
            }
            .padding(.horizontal , 6)
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("返回 (Esc)")
            
 
        


    }
}



//#Preview {
//    LyricsView()
//        .environment(PlayerManager())
//        .frame(width: 1200, height: 760)
//}

#Preview("歌词布局测试") {
    let player = LyricsPreviewData.makePlayer()

    LyricsView()
        .environment(player)
        .environment(ThemeManager.shared)
        .frame(width: 900, height: 760)
}
