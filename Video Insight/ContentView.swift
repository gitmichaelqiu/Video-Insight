//
//  ContentView.swift
//  Video Insight
//
//  Created by Michael Qiu on 11/23/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct LeftSidebarView: View {
    @ObservedObject var videoProcessor: VideoProcessor
    @Binding var selectedVideo: URL?
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !videoProcessor.videos.isEmpty {
                List(videoProcessor.videos) { videoData in
                    HStack {
                        Image(systemName: "film")
                        Text(videoData.url.lastPathComponent)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedVideo = videoData.url
                    }
                    .contextMenu {
                        Button(role: .destructive, action: {
                            videoProcessor.removeVideo(url: videoData.url)
                            if selectedVideo == videoData.url {
                                selectedVideo = nil
                            }
                        }) {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .background(selectedVideo == videoData.url ? Color.accentColor.opacity(0.1) : Color.clear)
                }
                
                DropZoneView(isTargeted: isTargeted)
                    .padding(16)
                    .frame(height: 152)
            } else {
                DropZoneView(isTargeted: isTargeted)
                    .padding(16)
                    .frame(maxHeight: .infinity)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url = url, error == nil else { return }
                
                if UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true {
                    do {
                        let bookmarkData = try url.bookmarkData(
                            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        
                        var isStale = false
                        guard let resolvedURL = try? URL(
                            resolvingBookmarkData: bookmarkData,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale
                        ) else { return }
                        
                        DispatchQueue.main.async {
                            selectedVideo = resolvedURL
                            if videoProcessor.handleVideoImport(url: resolvedURL) {
                                Task {
                                    try await videoProcessor.processVideo(url: resolvedURL)
                                }
                            }
                        }
                    } catch {
                        print("Error creating bookmark: \(error)")
                    }
                }
            }
            return true
        }
    }
}

struct DropZoneView: View {
    let isTargeted: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 32))
                .foregroundStyle(isTargeted ? .blue : .gray)
            Text("Drag video here")
                .foregroundStyle(isTargeted ? .blue : .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(isTargeted ? .blue : .gray.opacity(0.5))
        )
    }
}

struct ContentView: View {
    @StateObject private var videoProcessor = VideoProcessor()
    @StateObject private var settings = Settings()
    @State private var selectedVideo: URL?
    @State private var selectedFrame: VideoProcessor.VideoFrame?
    @State private var isShowingFilePicker = false
    @State private var activeSheet: ActiveSheet?
    
    private enum ActiveSheet: Identifiable {
        case settings
        case videoSummary
        
        var id: Self { self }
    }
    
    var body: some View {
        ThreeColumnLayout(
            videoProcessor: videoProcessor,
            settings: settings,
            selectedVideo: $selectedVideo,
            selectedFrame: $selectedFrame
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { activeSheet = .videoSummary }) {
                    Image(systemName: "text.quote")
                }
                .disabled(selectedVideo == nil)
                .keyboardShortcut("s", modifiers: [.option, .shift])
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isShowingFilePicker = true }) {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { activeSheet = .settings }) {
                    Image(systemName: "gear")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [UTType.movie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                processVideo(url: url)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings:
                SettingsView(settings: settings)
            case .videoSummary:
                if let url = selectedVideo {
                    VideoSummaryView(videoProcessor: videoProcessor, url: url, settings: settings)
                }
            }
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])
    }
    
    private func processVideo(url: URL) {
        selectedVideo = url
        if videoProcessor.handleVideoImport(url: url) {
            Task {
                try await videoProcessor.processVideo(url: url)
            }
        }
    }
}

struct ThreeColumnLayout: View {
    @ObservedObject var videoProcessor: VideoProcessor
    @ObservedObject var settings: Settings
    @Binding var selectedVideo: URL?
    @Binding var selectedFrame: VideoProcessor.VideoFrame?
    @State private var showingDeleteConfirmation = false
    @State private var videoToDelete: URL?
    
    var selectedVideoData: VideoProcessor.VideoData? {
        selectedVideo.flatMap { url in
            videoProcessor.videos.first(where: { $0.url == url })
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            NavigationView {
                LeftSidebarView(
                    videoProcessor: videoProcessor,
                    selectedVideo: $selectedVideo
                )
                .frame(minWidth: 200)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button(action: toggleSidebar) {
                            Image(systemName: "sidebar.left")
                        }
                    }
                }
                
                if let data = selectedVideoData {
                    if data.progress > 0 && data.progress < 1 {
                        ProcessingView(progress: data.progress)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let frame = selectedFrame {
                        MainContentView(frame: frame, videoURL: selectedVideo, videoProcessor: videoProcessor, settings: settings)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ContentPlaceholderView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ContentPlaceholderView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            Divider()
            
            TimelineView(
                videoProcessor: videoProcessor,
                selectedVideo: selectedVideo,
                selectedFrame: $selectedFrame
            )
        }
        .onKeyPress(phases: .down) { event in
            guard event.modifiers.contains(.command),
                  !event.modifiers.contains(.shift),
                  !event.modifiers.contains(.option),
                  !event.modifiers.contains(.control)
            else { return .ignored }
            
            switch event.key {
                case .init("d"):
                    if !videoProcessor.videos.isEmpty {
                        videoToDelete = selectedVideo ?? videoProcessor.videos[0].url
                        showingDeleteConfirmation = true
                    }
                    return .handled
                case .init("1"): selectVideo(at: 0)
                case .init("2"): selectVideo(at: 1)
                case .init("3"): selectVideo(at: 2)
                case .init("4"): selectVideo(at: 3)
                case .init("5"): selectVideo(at: 4)
                case .init("6"): selectVideo(at: 5)
                case .init("7"): selectVideo(at: 6)
                case .init("8"): selectVideo(at: 7)
                case .init("9"): selectLastVideo()
                default: return .ignored
            }
            return .handled
        }
        .alert("Remove Video", isPresented: $showingDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                if let url = videoToDelete {
                    videoProcessor.removeVideo(url: url)
                    if selectedVideo == url {
                        selectedVideo = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                videoToDelete = nil
            }
        } message: {
            if let url = videoToDelete {
                Text("Do you want to remove \(url.lastPathComponent)?")
            }
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    private func selectVideo(at index: Int) {
        if index < videoProcessor.videos.count {
            selectedVideo = videoProcessor.videos[index].url
        }
    }
    
    private func selectLastVideo() {
        if !videoProcessor.videos.isEmpty {
            selectedVideo = videoProcessor.videos.last?.url
        }
    }
}
