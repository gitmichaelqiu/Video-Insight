import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            TextField("Ollama API", text: $settings.ollamaURL)
                .focusable(false)
            TextField("Ollama Model", text: $settings.ollamaModel)
                .focusable(false)
            
            Picker("Copy Format", selection: $settings.summaryCopyFormat) {
                ForEach(SummaryCopyFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
        }
        .padding()
        .frame(width: 300)
        .onDisappear {
            // Restore focus to the main window when settings is dismissed
            if let mainWindow = NSApp.windows.first(where: { $0.isKeyWindow }) {
                mainWindow.makeFirstResponder(mainWindow.contentView)
            }
        }
    }
} 