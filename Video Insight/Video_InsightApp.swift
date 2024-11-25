//
//  Video_InsightApp.swift
//  Video Insight
//
//  Created by Michael Qiu on 11/23/24.
//

import SwiftUI

@main
struct Video_InsightApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        // .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
