import SwiftUI
import AVKit

struct MainContentView: View {
    let frame: VideoProcessor.VideoFrame
    let videoURL: URL?
    @ObservedObject var videoProcessor: VideoProcessor
    @ObservedObject var settings: Settings
    @State private var showingSettings = false
    @State private var showingSummary = false
    @State private var currentPlayer: AVPlayer?
    
    private func goToFrame() {
        if let player = currentPlayer {
            player.seek(to: CMTime(seconds: frame.timestamp, preferredTimescale: 600))
            player.pause()
        }
    }
    
    var body: some View {
        HSplitView {
            VSplitView {
                // Video Preview
                VStack {
                    if let url = videoURL {
                        VideoPlayerView(
                            url: url, 
                            currentTime: frame.timestamp,
                            onSeek: { player in
                                currentPlayer = player
                            }
                        )
                        .id(url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        Image(nsImage: frame.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 20)
                    }
                }
                .frame(minHeight: 300)
                
                // OCR Result
                VStack(alignment: .leading) {
                    HStack {
                        Text("OCR Result")
                            .font(.headline)
                        Spacer()
                        
                        Button(action: goToFrame) {
                            Image(systemName: "arrow.forward.to.line")
                            Text("Go to Frame")
                        }
                        .padding(.trailing, 8)
                        .keyboardShortcut("r", modifiers: .command)
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            if let tiffData = frame.image.tiffRepresentation {
                                NSPasteboard.general.setData(tiffData, forType: .tiff)
                            }
                        }) {
                            Image(systemName: "photo.on.rectangle")
                            Text("Copy Image")
                        }
                        .padding(.trailing, 8)
                        .keyboardShortcut("c", modifiers: [.option, .shift])
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(frame.ocrText, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Text")
                        }
                        .padding(.trailing, 8)
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                        
                        Button(action: { showingSummary.toggle() }) {
                            Image(systemName: "text.quote")
                            Text("Summarize")
                        }
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                    }
                    
                    ScrollView {
                        Text(frame.ocrText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .frame(minHeight: 200)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if showingSummary {
                SummaryView(text: frame.ocrText, existingSummary: frame.summary, settings: settings) { summary in
                    if let url = videoURL {
                        Task {
                            await MainActor.run {
                                videoProcessor.updateSummary(for: url, frameId: frame.id, summary: summary)
                            }
                        }
                    }
                }
                .frame(width: 300)
            }
        }
        .onAppear {
            showingSummary = frame.summary != nil
        }
        .onChange(of: frame.id) { _ in
            showingSummary = frame.summary != nil
        }
        .onChange(of: frame.summary) { newValue in
            showingSummary = newValue != nil
        }
    }
}

struct ProcessingView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView("Processing video...", value: progress)
                .progressViewStyle(.linear)
                .frame(width: 300)
            Text("\(Int(progress * 100))%")
                .foregroundStyle(.secondary)
        }
    }
}

struct ContentPlaceholderView: View {
    var body: some View {
        Text("Select a frame to view details")
            .foregroundStyle(.secondary)
    }
} 
