import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @Binding var player: AVPlayer?
    
    @State private var isPlaying = false
    @State private var timeObserver: Any? = nil
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                cleanup()
            }
            .onChange(of: url) { newURL in
                setupPlayer()
            }
            .onPlayPauseToggle(toggle: togglePlayback)
    }
    
    private func setupPlayer() {
        if let currentItem = player?.currentItem,
           let currentURL = (currentItem.asset as? AVURLAsset)?.url,
           currentURL == url {
            return
        }
        
        player?.replaceCurrentItem(with: AVPlayerItem(url: url))
        
        addTimeObserver()
    }
    
    private func cleanup() {
        removeTimeObserver()
        player?.pause()
        player = nil
    }
    
    private func addTimeObserver() {
        guard let player = player, timeObserver == nil else { return }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            isPlaying = player.rate > 0
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

struct PlayPauseToggle: ViewModifier {
    @State private var isPlaying: Bool = false
    let togglePlayback: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                togglePlayback()
                isPlaying.toggle()
            }
    }
}

extension View {
    func onPlayPauseToggle(toggle: @escaping () -> Void) -> some View {
        self.modifier(PlayPauseToggle(togglePlayback: toggle))
    }
} 
