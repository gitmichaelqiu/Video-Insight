//
//  Video_InsightApp.swift
//  Video Insight
//
//  Created by Michael Qiu on 11/23/24.
//

import SwiftUI

@main
struct Video_InsightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var videoProcessor = VideoProcessor()
    @StateObject private var settings = Settings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(videoProcessor)
                .environmentObject(settings)
                .onAppear {
                    print("App initialized successfully")
                }
                .onDisappear {
                    print("App cleaning up")
                }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create necessary directories
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("Video-Insight")
        
        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error creating app directory: \(error)")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup temporary files
        let fileManager = FileManager.default
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let appTempDirectory = tempDirectory.appendingPathComponent("Video-Insight")
        
        try? fileManager.removeItem(at: appTempDirectory)
    }
}
