import Foundation
import Network

class OllamaService {
    let settings: Settings
    
    init(settings: Settings) {
        self.settings = settings
    }
    
    func summarize(text: String) async throws -> String {
        let baseURL = settings.ollamaURL.hasPrefix("http") ? settings.ollamaURL : "http://\(settings.ollamaURL)"
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw NSError(domain: "OllamaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // First check if we can reach the host
        let monitor = NWPathMonitor()
        let canReachHost = await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue.global())
        }
        
        guard canReachHost else {
            throw NSError(domain: "OllamaService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Cannot reach Ollama server. Please check if it's running."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let prompt = """
        Summarize the provided text with the following format:

        ## <concise and easy-to-read title>

        <one to two sentence summary with the most important information>

        ### Key Takeaways

        - <several bullet points with the key takeaways, keep the bullet points as short as possible>

        ---
        
        Some rules to follow precisely:
        - follow the format STRICTLY
        - REMEMBER to generate the title
        - NEVER come up with additional information
        - NEVER mention the source of the text

        ---
        
        Here's the text to summarize:

        \(text)
        """
        
        let requestBody: [String: Any] = [
            "model": settings.ollamaModel,
            "prompt": prompt,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("Debug - Attempting connection to: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "OllamaService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Debug - Server error: \(errorMessage)")
                throw NSError(domain: "OllamaService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorMessage)"])
            }
            
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = jsonObject["response"] as? String else {
                throw NSError(domain: "OllamaService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            return response
            
        } catch {
            print("Debug - Error details: \(error)")
            throw error
        }
    }
} 