import SwiftUI
import MarkdownUI

struct VideoSummaryView: View {
    let videoProcessor: VideoProcessor
    let url: URL
    @ObservedObject var settings: Settings
    @State private var summary: String = ""
    @State private var isLoading = false
    @State private var error: String?
    
    private var existingSummary: String? {
        videoProcessor.videos.first(where: { $0.url == url })?.summary
    }
    
    private func copyText() {
        NSPasteboard.general.clearContents()
        
        switch settings.summaryCopyFormat {
        case .plainText:
            let plainText = summary
                .replacingOccurrences(of: "##### ", with: "")
                .replacingOccurrences(of: "#### ", with: "")
                .replacingOccurrences(of: "### ", with: "")
                .replacingOccurrences(of: "## ", with: "")
                .replacingOccurrences(of: "# ", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: "> ", with: "")
                .replacingOccurrences(of: "- ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            NSPasteboard.general.setString(plainText, forType: .string)
        case .markdown:
            NSPasteboard.general.setString(summary, forType: .string)
        }
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Generating video summary...")
                    .frame(maxHeight: .infinity, alignment: .center)
            } else if let error = error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                VStack {
                    ScrollView {
                        Markdown(summary.isEmpty ? "No summary yet" : summary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    
                    Divider()
                    
                    HStack {
                        Button(action: copyText) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        
                        Button(action: { Task { await generateSummary() } }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Re-summarize")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                    .disabled(summary.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 500, height: 600)
        .task {
            if let existing = existingSummary {
                summary = existing
            } else {
                await generateSummary()
            }
        }
    }
    
    private func generateSummary() async {
        isLoading = true
        do {
            let frames = videoProcessor.videos.first(where: { $0.url == url })?.frames ?? []
            let combinedText = frames.map { $0.ocrText }.joined(separator: "\n\n")
            let service = OllamaService(settings: settings)
            summary = try await service.summarize(text: combinedText)
            videoProcessor.updateVideoSummary(for: url, summary: summary)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
} 