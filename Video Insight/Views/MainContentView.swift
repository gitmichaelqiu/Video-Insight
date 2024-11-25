import SwiftUI
import AVKit

struct MainContentView: View {
    let frame: VideoProcessor.VideoFrame
    let videoURL: URL?
    @ObservedObject var videoProcessor: VideoProcessor
    @ObservedObject var settings: Settings
    @State private var showingSettings = false
    @State private var showingSummary = false
    @State private var player: AVPlayer? = nil
    @State private var currentSummary: String? = nil
    @State private var editedOCRText: String = ""
    @State private var isEditing = false
    
    private var isTextModified: Bool {
        if let originalText = videoProcessor.getOriginalOCRText(for: frame.id) {
            return originalText != editedOCRText
        }
        return false
    }
    
    func goToCurrentFrame() {
        guard let player = player else { return }
        
        if let currentURL = (player.currentItem?.asset as? AVURLAsset)?.url,
           currentURL != videoURL {
            player.replaceCurrentItem(with: AVPlayerItem(url: videoURL!))
        }
        
        let time = CMTime(seconds: frame.timestamp, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            if finished {
                player.pause()
            }
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
                            player: $player
                        )
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
                        Text("OCR")
                            .font(.headline)
                        Spacer()
                        
                        if isTextModified {
                            Button(action: {
                                if let originalText = videoProcessor.getOriginalOCRText(for: frame.id) {
                                    editedOCRText = originalText
                                    if let url = videoURL {
                                        videoProcessor.updateOCRText(for: url, frameId: frame.id, text: originalText)
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset")
                                }
                            }
                            .padding(.trailing, 8)
                            .keyboardShortcut("r", modifiers: [.command, .shift])
                            .help("⌘⇧R")
                        }
                        
                        Button(action: { isEditing.toggle() }) {
                            HStack {
                                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                                Text(isEditing ? "Done" : "Edit")
                            }
                        }
                        .padding(.trailing, 8)
                        .keyboardShortcut("e", modifiers: .command)
                        .help("⌘E")
                        
                        Button(action: goToCurrentFrame) {
                            HStack {
                                Image(systemName: "arrow.forward.to.line")
                                Text("Jump")
                            }
                        }
                        .padding(.trailing, 8)
                        .keyboardShortcut("r", modifiers: .command)
                        .help("⌘R")
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            if let tiffData = frame.image.tiffRepresentation {
                                NSPasteboard.general.setData(tiffData, forType: .tiff)
                            }
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Copy Image")
                            }
                        }
                        .padding(.trailing, 8)
                        .keyboardShortcut("c", modifiers: [.option, .shift])
                        .help("⌥⇧C")
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(editedOCRText, forType: .string)
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Text")
                            }
                        }
                        .padding(.trailing, 8)
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                        .help("⌘⇧C")
                        
                        Button(action: { showingSummary.toggle() }) {
                            HStack {
                                Image(systemName: "text.quote")
                                Text("Summarize")
                            }
                        }
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                        .help("⌘⇧S")
                    }
                    
                    ScrollView {
                        if isEditing {
                            TextEditor(text: $editedOCRText)
                                .frame(maxWidth: .infinity, minHeight: 100)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            Text(editedOCRText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .frame(minHeight: 200)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if showingSummary {
                SummaryView(
                    text: editedOCRText,
                    existingSummary: currentSummary ?? frame.summary,
                    autoGenerate: (currentSummary ?? frame.summary) == nil,
                    settings: settings
                ) { summary in
                    if let url = videoURL {
                        Task {
                            await MainActor.run {
                                currentSummary = summary
                                videoProcessor.updateSummary(for: url, frameId: frame.id, summary: summary)
                            }
                        }
                    }
                }
                .frame(width: 300)
            }
        }
        .onAppear {
            editedOCRText = videoProcessor.getEditedOCRText(for: frame.id) ?? frame.ocrText
            if let url = videoURL {
                if videoProcessor.getEditedOCRText(for: frame.id) == nil {
                    videoProcessor.updateOCRText(for: url, frameId: frame.id, text: frame.ocrText)
                }
            }
            showingSummary = frame.summary != nil
            currentSummary = frame.summary
            
            if let url = videoURL, player == nil {
                player = AVPlayer(url: url)
                seekToCurrentFrame()
            }
        }
        .onChange(of: frame.id) { _ in
            editedOCRText = videoProcessor.getEditedOCRText(for: frame.id) ?? frame.ocrText
            if let url = videoURL {
                if videoProcessor.getEditedOCRText(for: frame.id) == nil {
                    videoProcessor.updateOCRText(for: url, frameId: frame.id, text: frame.ocrText)
                }
            }
            showingSummary = frame.summary != nil
            currentSummary = frame.summary
            seekToCurrentFrame()
        }
        .onChange(of: frame.summary) { newValue in
            showingSummary = newValue != nil
            currentSummary = newValue
        }
        .onChange(of: videoURL) { newURL in
            if let url = newURL {
                player = AVPlayer(url: url)
                seekToCurrentFrame()
            } else {
                player = nil
            }
        }
        .onChange(of: editedOCRText) { newValue in
            if let url = videoURL {
                videoProcessor.updateOCRText(for: url, frameId: frame.id, text: newValue)
            }
        }
    }
    
    private func seekToCurrentFrame() {
        guard let player = player else { return }
        
        if let currentURL = (player.currentItem?.asset as? AVURLAsset)?.url,
           currentURL != videoURL {
            player.replaceCurrentItem(with: AVPlayerItem(url: videoURL!))
        }
        
        let time = CMTime(seconds: frame.timestamp, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            if finished {
                player.pause()
            }
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
