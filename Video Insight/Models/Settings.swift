import Foundation

enum SummaryCopyFormat: String, CaseIterable {
    case plainText = "Plain Text"
    case markdown = "Markdown"
}

class Settings: ObservableObject {
    @Published var ollamaURL: String {
        didSet {
            UserDefaults.standard.set(ollamaURL, forKey: "ollamaURL")
        }
    }
    
    @Published var ollamaModel: String {
        didSet {
            UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel")
        }
    }
    
    @Published var summaryCopyFormat: SummaryCopyFormat {
        didSet {
            UserDefaults.standard.set(summaryCopyFormat.rawValue, forKey: "summaryCopyFormat")
        }
    }
    
    init() {
        self.ollamaURL = UserDefaults.standard.string(forKey: "ollamaURL") ?? "localhost:11434"
        self.ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "mistral"
        let formatString = UserDefaults.standard.string(forKey: "summaryCopyFormat") ?? SummaryCopyFormat.plainText.rawValue
        self.summaryCopyFormat = SummaryCopyFormat(rawValue: formatString) ?? .plainText
    }
} 