import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    let currentTime: Double
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    let onSeek: (AVPlayer) -> Void
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: url)
                player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                player?.pause()
                if let player = player {
                    onSeek(player)
                }
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
            .onChange(of: currentTime) { newTime in
                player?.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                player?.pause()
                isPlaying = false
            }
            .onTapGesture {
                if isPlaying {
                    player?.pause()
                } else {
                    player?.play()
                }
                isPlaying.toggle()
            }
    }
} 