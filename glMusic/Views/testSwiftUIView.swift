//
//  testSwiftUIView.swift
//  glMusic
//
//  Created by go love on 11/1/26.
//

import SwiftUI


struct testSwiftUIView: View {
    @Environment(PlayerManager.self) private var player
    var body: some View {
        @Bindable var player = player
        VStack(spacing: 0){
            Rectangle()
                .fill(Color.cyan)
                .frame(height: 65)
            ProgressSlider(value: $player.volume,trackHeight: 6)
        }
    }
}

#Preview {
    testSwiftUIView()
        .environment(PlayerManager())
}
