import Vision
import AppKit
import AVFoundation

class VideoProcessor: ObservableObject {
    @Published var videos: [VideoData] = []
    
    struct VideoData: Identifiable {
        let id = UUID()
        let url: URL
        var frames: [VideoFrame]
        var lastSelectedFrameId: UUID?
        var progress: Double
        var summary: String?
    }
    
    struct VideoFrame: Identifiable {
        let id = UUID()
        let image: NSImage
        let timestamp: Double
        let ocrText: String
        var summary: String? = nil
    }
    
    func addVideo(url: URL) {
        DispatchQueue.main.async {
            self.videos.append(VideoData(url: url, frames: [], lastSelectedFrameId: nil, progress: 0))
        }
    }
    
    func updateLastSelectedFrame(for url: URL, frameId: UUID) {
        if let index = videos.firstIndex(where: { $0.url == url }) {
            videos[index].lastSelectedFrameId = frameId
        }
    }
    
    func processVideo(url: URL) async throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "VideoInsight", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot access video file"])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        updateProgress(for: url, progress: 0)
        
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero
        
        var frames: [VideoFrame] = []
        let totalSeconds = CMTimeGetSeconds(duration)
        var currentTime: Double = 0
        var lastOCRText: String?
        
        while currentTime < totalSeconds {
            let time = CMTime(seconds: currentTime, preferredTimescale: 600)
            let image = try generator.copyCGImage(at: time, actualTime: nil)
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            
            if let ocrText = try await performOCR(image: nsImage),
               !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if lastOCRText == nil || !isTextSimilar(ocrText, lastOCRText!) {
                    frames.append(VideoFrame(image: nsImage, timestamp: currentTime, ocrText: ocrText))
                    lastOCRText = ocrText
                }
            }
            
            currentTime += 1.0
            updateProgress(for: url, progress: currentTime / totalSeconds)
        }
        
        DispatchQueue.main.async {
            if let index = self.videos.firstIndex(where: { $0.url == url }) {
                self.videos[index].frames = frames
                self.videos[index].progress = 1.0
                if let firstFrame = frames.first {
                    self.updateLastSelectedFrame(for: url, frameId: firstFrame.id)
                }
            }
        }
    }
    
    private func performOCR(image: NSImage) async throws -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest()
        try requestHandler.perform([request])
        
        guard let observations = request.results else { return nil }
        let text = observations.compactMap({ $0.topCandidates(1).first?.string }).joined(separator: "\n")
        return text.isEmpty ? nil : text
    }
    
    func updateProgress(for url: URL, progress: Double) {
        DispatchQueue.main.async {
            if let index = self.videos.firstIndex(where: { $0.url == url }) {
                self.videos[index].progress = progress
                
                // When processing completes, select the first frame
                if progress >= 1.0, let firstFrame = self.videos[index].frames.first {
                    self.videos[index].lastSelectedFrameId = firstFrame.id
                }
            }
        }
    }
    
    func handleVideoImport(url: URL) -> Bool {
        // Check if video already exists
        if let existingVideo = videos.first(where: { $0.url == url }) {
            return false
        }
        
        addVideo(url: url)
        return true
    }
    
    func updateSummary(for url: URL, frameId: UUID, summary: String) {
        if let videoIndex = videos.firstIndex(where: { $0.url == url }),
           let frameIndex = videos[videoIndex].frames.firstIndex(where: { $0.id == frameId }) {
            videos[videoIndex].frames[frameIndex].summary = summary
        }
    }
    
    private func isTextSimilar(_ text1: String, _ text2: String) -> Bool {
        // Convert texts to lowercase and split into words
        let words1 = text1.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let words2 = text2.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // If either text is empty, they're not similar
        if words1.isEmpty || words2.isEmpty {
            return false
        }
        
        // Identify shorter and longer text
        let (shorterWords, longerWords) = words1.count < words2.count 
            ? (words1, words2) 
            : (words2, words1)
        
        // Count how many words from the shorter text appear in the longer text
        var matchCount = 0
        for word in shorterWords {
            if longerWords.contains(where: { $0.contains(word) || word.contains($0) }) {
                matchCount += 1
            }
        }
        
        // Calculate similarity ratio
        let similarity = Double(matchCount) / Double(shorterWords.count)
        return similarity > 0.8
    }
    
    private func levenshteinDistance(_ text1: String, _ text2: String) -> Int {
        let empty = Array(repeating: 0, count: text2.count + 1)
        var last = Array(0...text2.count)
        
        for (i, char1) in text1.enumerated() {
            var current = [i + 1] + empty
            for (j, char2) in text2.enumerated() {
                current[j + 1] = char1 == char2 ? last[j] : min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        return last[text2.count]
    }
    
    func updateVideoSummary(for url: URL, summary: String) {
        if let index = videos.firstIndex(where: { $0.url == url }) {
            videos[index].summary = summary
        }
    }
    
    func removeVideo(url: URL) {
        DispatchQueue.main.async {
            if let index = self.videos.firstIndex(where: { $0.url == url }) {
                self.videos.remove(at: index)
            }
        }
    }
}
