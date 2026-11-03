//
//  PlayerBar.swift
//  glMusic
//
//  Created by go love on 10/7/26.
//

import SwiftUI

struct PlayerBar: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovering = false
    var body: some View {
        HStack{
            // MARK: - Left · Song Info
            songInfoSection
                .frame(width: 150, alignment: .leading)

            Spacer(minLength: 8)

            // MARK: - Center · Controls + Progress
            controlsSection

            Spacer(minLength: 8)

            // MARK: - Right · Volume + Extras
            extrasSection
                .frame(width: 150, alignment: .trailing)
        }
        .frame(height: 42)
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
    }

    // MARK: - Song Info (Left)

    private var songInfoSection: some View {
        HStack(spacing: 12) {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    
                    .font(.system(size: 12))
                    .foregroundStyle(player.isShuffled ? themeManager.accentColor : .secondary)
                   
            }
            .buttonStyle(.plain)
         

            Button { player.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                   
            }
            .buttonStyle(.plain)

            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button { player.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button { player.cycleRepeat() } label: {
                Image(systemName: player.repeatMode.systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(player.repeatMode.isActive ? themeManager.accentColor : .secondary)
            }
            .buttonStyle(.plain)
        }
       
    }

    // MARK: - Controls (Center)

    private var controlsSection: some View {
        @Bindable var player = player
       
       
//        var isHover = false
        return VStack(alignment:.leading,spacing:0) {
           
            HStack{
                if let song = player.currentSong {
                    // Album art from API
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            player.isShowingLyrics.toggle()
                        }
                    } label: {
                        Group {
                            if let localURL = DownloadManager.shared.localCoverURL(for: song.id),
                               let img = NSImage(contentsOf: localURL) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                AsyncImage(url: URL(string: song.coverUrl ?? "")) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Rectangle().fill(.quaternary)
                                            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
                                    }
                                }
                            }
                        }
                        .overlay(content: {
                            if isHovering{
                                Image(systemName: "arrow.down.backward.and.arrow.up.forward.rectangle.fill")
                                .font(.system(size: 24))
                                    
                             
                             }
                        })
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
                    .buttonStyle(.plain)

                    
                    

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(song.displayArtist)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    if player.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Spacer()
                    Button {
                        player.toggleLike(for: song)
                    } label: {
                        Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .secondary)
                    }
                    .frame(width: 28, height: 28)
                    .buttonStyle(.plain)
                    .help(player.isLiked(song.id) ? "取消喜欢" : "喜欢这首歌")

                    // 下载此歌曲
                    DownloadButton(song: song, iconSize: 13)
                        .frame(width: 28, height: 28)

                  
                    
                    
                } else {
                    RoundedRectangle(cornerRadius: 6)
                       

                        .fill(.quaternary)
                        
                        .frame(width: 38, height: 38)
                       
                    
                                                .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 20))
                                .foregroundStyle(.tertiary)
                        )
                    
                
                    VStack(alignment: .leading, spacing: 2) {
                        Text("未在播放")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                
                
                
                
            }
            
            .frame( height: 38)
            .padding(.top,2)
//            .padding(.horizontal,40)
            

            
            

            ProgressSlider(value: $player.progress, trackHeight: 3)
                .padding(.top,2)
        }
        .frame(height: 42)
    }

    // MARK: - Extras (Right)

    private var extrasSection: some View {
        @Bindable var player = player

        return HStack(spacing: 14) {
//            Button {
//                withAnimation(.easeInOut(duration: 0.25)) {
//                    player.isShowingLyrics.toggle()
//                }
//            } label: {
//                Image(systemName: player.isShowingLyrics ? "quote.bubble.fill" : "quote.bubble")
//                    .font(.system(size: 13))
//                    .foregroundStyle(player.isShowingLyrics ? .pink : .secondary)
//            }
//            .buttonStyle(.plain)
//            .help("歌词")

            Button {
                player.isShowingQueue.toggle()
            } label: {
                Image(systemName: player.isShowingQueue ? "list.bullet.rectangle.fill" : "list.bullet")
                    .font(.system(size: 13))
                    .foregroundStyle(player.isShowingQueue ? themeManager.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("待播清单")
            .popover(isPresented: $player.isShowingQueue, arrowEdge: .top) {
                QueueView()
            }

            HStack(spacing: 8) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                ProgressSlider(value: $player.volume, trackHeight: 3)
                    .frame(width: 96)
            }
        }
    }

    private var volumeIcon: String {
        if player.volume == 0    { return "speaker.slash.fill" }
        if player.volume < 0.33  { return "speaker.wave.1.fill" }
        if player.volume < 0.66  { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Custom Progress Slider

struct ProgressSlider: View {
    @Binding var value: Double
    var trackHeight:Double
    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let trackH: CGFloat = (isHovering || isDragging) ? 6 : trackHeight
//            let thumbSize: CGFloat = (isHovering || isDragging) ? 12 : 0

            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary).frame(height: trackH)
                Capsule().fill(.primary.opacity(0.8))
                    .frame(width: max(0, w * value), height: trackH)
//                if thumbSize > 0 {
//                    Circle().fill(.white)
//                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
//                        .frame(width: thumbSize, height: thumbSize)
//                        .offset(x: max(0, w * value - thumbSize / 2))
//                }
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        value = min(max(drag.location.x / w, 0), 1)
                    }
                    .onEnded { _ in isDragging = false }
            )
            .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
        }
        .frame(height: 8)
    }
}

#Preview {
    PlayerBar()
        .environment(PlayerManager())
        .frame(width: 800)
}
