//
//  ContentView.swift
//  Video Insight
//
//  Created by Michael Qiu on 11/23/24.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

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
                    .help(videoData.url.lastPathComponent)
                    .contextMenu {
                        Button(role: .destructive, action: {
                            videoProcessor.removeVideo(url: videoData.url)
                            if selectedVideo == videoData.url {
                                selectedVideo = nil
                            }
                        }) {
                            Label("Remove", systemImage: "trash")
                        }
                        .keyboardShortcut("d", modifiers: .command)
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
            Text("Drop video here")
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
                    Label("Summarize Video", systemImage: "text.quote")
                }
                .disabled(selectedVideo == nil)
                .keyboardShortcut("s", modifiers: [.option, .shift])
                .help("⌥⇧S")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isShowingFilePicker = true }) {
                    Label("Open Video", systemImage: "plus")
                }
                .keyboardShortcut("o", modifiers: .command)
                .help("⌘O")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { activeSheet = .settings }) {
                    Label("Settings", systemImage: "gear")
                }
                .keyboardShortcut(",", modifiers: .command)
                .help("⌘,")
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
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isFocused: Bool
    @State private var keyboardMonitor: Any?
    
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
                            Label("Toggle Sidebar", systemImage: "sidebar.left")
                        }
                        .help("⌘⇧L")
                    }
                }
                
                if let data = selectedVideoData {
                    if data.progress > 0 && data.progress < 1 {
                        ProcessingView(progress: data.progress)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let frame = selectedFrame {
                        MainContentView(frame: frame, videoURL: selectedVideo, videoProcessor: videoProcessor, settings: settings)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(frame.id)
                    } else {
                        ContentPlaceholderView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ContentPlaceholderView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            TimelineView(
                videoProcessor: videoProcessor,
                selectedVideo: selectedVideo,
                selectedFrame: $selectedFrame,
                goToCurrentFrame: {
                    if let frame = selectedFrame {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("GoToCurrentFrame"),
                            object: frame
                        )
                    }
                }
            )
            .frame(width: 200)
        }
        .focused($isFocused)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                isFocused = true
            }
        }
        .background(
            Menu("Hidden Menu") {
                Button("Select Video 1") { selectVideo(at: 0) }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Select Video 2") { selectVideo(at: 1) }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("Select Video 3") { selectVideo(at: 2) }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("Select Video 4") { selectVideo(at: 3) }
                    .keyboardShortcut("4", modifiers: [.command])
                Button("Select Video 5") { selectVideo(at: 4) }
                    .keyboardShortcut("5", modifiers: [.command])
                Button("Select Video 6") { selectVideo(at: 5) }
                    .keyboardShortcut("6", modifiers: [.command])
                Button("Select Video 7") { selectVideo(at: 6) }
                    .keyboardShortcut("7", modifiers: [.command])
                Button("Select Video 8") { selectVideo(at: 7) }
                    .keyboardShortcut("8", modifiers: [.command])
                Button("Select Last Video") { selectLastVideo() }
                    .keyboardShortcut("9", modifiers: [.command])
                Button("Delete Video") { handleDelete() }
                    .keyboardShortcut("d", modifiers: [.command])
            }
            .hidden()
        )
        .keyboardShortcut("l", modifiers: [.command, .shift])
        .modifier(NumberShortcuts1to3(
            videoProcessor: videoProcessor,
            selectedVideo: $selectedVideo
        ))
        .modifier(NumberShortcuts4to6(
            videoProcessor: videoProcessor,
            selectedVideo: $selectedVideo
        ))
        .modifier(NumberShortcuts7to9(
            videoProcessor: videoProcessor,
            selectedVideo: $selectedVideo
        ))
        .modifier(DeleteShortcut(
            videoProcessor: videoProcessor,
            videoToDelete: $videoToDelete,
            showingDeleteConfirmation: $showingDeleteConfirmation,
            selectedVideo: $selectedVideo
        ))
        .alert("Remove Video", isPresented: $showingDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                if let url = videoToDelete {
                    videoProcessor.removeVideo(url: url)
                    if selectedVideo == url {
                        selectedVideo = nil
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            
            Button("Cancel", role: .cancel) {
                videoToDelete = nil
            }
            .keyboardShortcut(.cancelAction)
        } message: {
            if let url = videoToDelete {
                Text("Do you want to remove \(url.lastPathComponent)?")
            }
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
        .onDisappear {
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    private func setupKeyboardShortcuts() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }
            
            if let keyChar = event.characters?.first {
                switch keyChar {
                case "1": 
                    selectVideo(at: 0)
                    return nil
                case "2": 
                    selectVideo(at: 1)
                    return nil
                case "3": 
                    selectVideo(at: 2)
                    return nil
                case "4": 
                    selectVideo(at: 3)
                    return nil
                case "5": 
                    selectVideo(at: 4)
                    return nil
                case "6": 
                    selectVideo(at: 5)
                    return nil
                case "7": 
                    selectVideo(at: 6)
                    return nil
                case "8": 
                    selectVideo(at: 7)
                    return nil
                case "9": 
                    selectLastVideo()
                    return nil
                default: 
                    return event
                }
            }
            return event
        }
    }
    
    private func selectVideo(at index: Int) {
        guard !videoProcessor.videos.isEmpty else { return }
        if index < videoProcessor.videos.count {
            selectedVideo = videoProcessor.videos[index].url
        }
    }
    
    private func selectLastVideo() {
        guard !videoProcessor.videos.isEmpty else { return }
        selectedVideo = videoProcessor.videos.last?.url
    }
    
    private func handleDelete() {
        if !videoProcessor.videos.isEmpty {
            videoToDelete = selectedVideo ?? videoProcessor.videos[0].url
            showingDeleteConfirmation = true
        }
    }
}

private struct NumberShortcuts1to3: ViewModifier {
    let videoProcessor: VideoProcessor
    @Binding var selectedVideo: URL?
    
    func body(content: Content) -> some View {
        content
            .keyboardShortcut(KeyEquivalent("1"), modifiers: [.command])
            .keyboardShortcut(KeyEquivalent("2"), modifiers: [.command])
            .keyboardShortcut(KeyEquivalent("3"), modifiers: [.command])
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                NSApp.mainWindow?.makeFirstResponder(nil)
            }
    }
    
    private func selectVideo(at index: Int) {
        guard !videoProcessor.videos.isEmpty else { return }
        if index < videoProcessor.videos.count {
            selectedVideo = videoProcessor.videos[index].url
        }
    }
}

private struct NumberShortcuts4to6: ViewModifier {
    let videoProcessor: VideoProcessor
    @Binding var selectedVideo: URL?
    
    func body(content: Content) -> some View {
        content
            .keyboardShortcut(KeyEquivalent("4"), modifiers: [.command])
            .keyboardShortcut(KeyEquivalent("5"), modifiers: [.command])
            .keyboardShortcut(KeyEquivalent("6"), modifiers: [.command])
    }
    
    private func selectVideo(at index: Int) {
        guard !videoProcessor.videos.isEmpty else { return }
        if index < videoProcessor.videos.count {
            selectedVideo = videoProcessor.videos[index].url
        }
    }
}

private struct NumberShortcuts7to9: ViewModifier {
    let videoProcessor: VideoProcessor
    @Binding var selectedVideo: URL?
    
    func body(content: Content) -> some View {
        content
            .keyboardShortcut(KeyEquivalent("7"), modifiers: [.command])
            .keyboardShortcut(KeyEquivalent("8"), modifiers: [.command])
            .keyboardShortcut(KeyEquivalent("9"), modifiers: [.command])
    }
    
    private func selectVideo(at index: Int) {
        guard !videoProcessor.videos.isEmpty else { return }
        if index < videoProcessor.videos.count {
            selectedVideo = videoProcessor.videos[index].url
        }
    }
    
    private func selectLastVideo() {
        guard !videoProcessor.videos.isEmpty else { return }
        selectedVideo = videoProcessor.videos.last?.url
    }
}

private struct DeleteShortcut: ViewModifier {
    let videoProcessor: VideoProcessor
    @Binding var videoToDelete: URL?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var selectedVideo: URL?
    
    func body(content: Content) -> some View {
        content
            .keyboardShortcut(KeyEquivalent("d"), modifiers: [.command])
    }
    
    private func handleDelete() {
        if !videoProcessor.videos.isEmpty {
            videoToDelete = selectedVideo ?? videoProcessor.videos[0].url
            showingDeleteConfirmation = true
        }
    }
}
