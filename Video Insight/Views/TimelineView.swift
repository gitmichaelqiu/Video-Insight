import SwiftUI

struct TimelineView: View {
    @ObservedObject var videoProcessor: VideoProcessor
    let selectedVideo: URL?
    @Binding var selectedFrame: VideoProcessor.VideoFrame?
    
    var videoData: VideoProcessor.VideoData? {
        selectedVideo.flatMap { url in
            videoProcessor.videos.first(where: { $0.url == url })
        }
    }
    
    var body: some View {
        Group {
            if let data = videoData {
                if data.frames.isEmpty {
                    Text("No frames available")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(data.frames) { frame in
                                TimelineItemView(
                                    frame: frame,
                                    isSelected: frame.id == selectedFrame?.id
                                )
                                .onTapGesture {
                                    selectedFrame = frame
                                }
                            }
                        }
                        .padding()
                    }
                }
            } else {
                Text("Select a video")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 200)
    }
}

struct TimelineItemView: View {
    let frame: VideoProcessor.VideoFrame
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(nsImage: frame.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .cornerRadius(4)
            
            Text(timeString(from: frame.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 