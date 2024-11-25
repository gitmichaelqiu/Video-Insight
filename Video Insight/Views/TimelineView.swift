import SwiftUI

struct TimelineView: View {
    @ObservedObject var videoProcessor: VideoProcessor
    let selectedVideo: URL?
    @Binding var selectedFrame: VideoProcessor.VideoFrame?
    let goToCurrentFrame: () -> Void
    
    var videoData: VideoProcessor.VideoData? {
        videoProcessor.videos.first(where: { $0.url == selectedVideo })
    }
    
    var body: some View {
        List {
            if let data = videoData {
                if data.frames.isEmpty {
                    Text("Processing video...")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(data.frames) { frame in
                        TimelineFrameView(frame: frame, isSelected: frame.id == selectedFrame?.id)
                            .onTapGesture {
                                selectedFrame = frame
                                if let url = selectedVideo {
                                    videoProcessor.updateLastSelectedFrame(for: url, frameId: frame.id)
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(frame.id == selectedFrame?.id ? Color.accentColor.opacity(0.1) : Color.clear)
                    }
                }
            } else {
                Text("No video selected")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedVideo) { newValue in
            if let url = newValue,
               let data = videoProcessor.videos.first(where: { $0.url == url }) {
                if let lastSelectedId = data.lastSelectedFrameId,
                   let lastFrame = data.frames.first(where: { $0.id == lastSelectedId }) {
                    selectedFrame = lastFrame
                } else if let firstFrame = data.frames.first {
                    selectedFrame = firstFrame
                    videoProcessor.updateLastSelectedFrame(for: url, frameId: firstFrame.id)
                }
            }
        }
    }
}

struct TimelineFrameView: View {
    let frame: VideoProcessor.VideoFrame
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(nsImage: frame.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
            
            Text(timeString(from: frame.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(6)
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 