import SwiftUI
import MarkdownUI

struct SummaryView: View {
    let text: String
    let existingSummary: String?
    @ObservedObject var settings: Settings
    let onSummaryUpdate: (String) -> Void
    @State private var summary: String = ""
    @State private var isLoading = false
    @State private var error: String?
    
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
    
    private func generateSummary() async {
        isLoading = true
        do {
            let service = OllamaService(settings: settings)
            summary = try await service.summarize(text: text)
            onSummaryUpdate(summary)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Generating summary...")
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
        .frame(maxWidth: 300, maxHeight: .infinity)
        .task(id: existingSummary) {
            if let existing = existingSummary {
                summary = existing
                onSummaryUpdate(existing)
            } else {
                await generateSummary()
            }
        }
    }
} 