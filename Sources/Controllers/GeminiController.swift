import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool, timestamp: Date) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

class GeminiController: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var currentInput = ""
    
    private let apiKey: String
    private let apiURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    // Memory management - maksimum mesaj sayısı
    private let maxMessages = 50
    
    init() {
        // API anahtarını environment variable'dan al
        // Terminal'de: export GEMINI_API_KEY="your_api_key_here"
        self.apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        
        if apiKey.isEmpty {
            print("⚠️ Gemini API key not found. Set GEMINI_API_KEY environment variable.")
        }
    }
    
    func sendMessage(_ message: String) async {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !apiKey.isEmpty else {
            await addMessage("API anahtarı ayarlanmamış. Lütfen GEMINI_API_KEY environment variable'ını ayarlayın.", isUser: false)
            return
        }

        
        await MainActor.run {
            // Add user message
            let userMessage = ChatMessage(content: message, isUser: true, timestamp: Date())
            messages.append(userMessage)
            isLoading = true
            currentInput = ""
        }
        
        do {
            let response = try await callGeminiAPI(message: message)
            await addMessage(response, isUser: false)
        } catch {
            await addMessage("Hata: \(error.localizedDescription)", isUser: false)
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func addMessage(_ content: String, isUser: Bool) async {
        await MainActor.run {
            let message = ChatMessage(content: content, isUser: isUser, timestamp: Date())
            messages.append(message)
            
            // Memory management - eski mesajları temizle
            if messages.count > maxMessages {
                messages.removeFirst(messages.count - maxMessages)
            }
        }
    }
    
    private func callGeminiAPI(message: String) async throws -> String {
        guard let url = URL(string: "\(apiURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Tüm sohbet geçmişini oluştur
        var contents: [GeminiContent] = []
        
        // Önceki mesajları ekle (son 20 mesajla sınırlı - performans için)
        let recentMessages = messages.suffix(20)
        for chatMessage in recentMessages {
            let role = chatMessage.isUser ? "user" : "model"
            contents.append(GeminiContent(parts: [GeminiPart(text: chatMessage.content)], role: role))
        }
        
        // Şu anki mesajı ekle
        contents.append(GeminiContent(parts: [GeminiPart(text: message)], role: "user"))
        

        
        let requestBody = GeminiRequest(contents: contents)
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.httpError(nil)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw GeminiError.httpError(httpResponse)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        return geminiResponse.candidates.first?.content.parts.first?.text ?? "Yanıt alınamadı"
    }
    
    func clearChat() {
        messages.removeAll()
    }
}

// MARK: - API Models
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String?
    
    init(parts: [GeminiPart], role: String? = nil) {
        self.parts = parts
        self.role = role
    }
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
}

enum GeminiError: Error, LocalizedError {
    case invalidURL
    case httpError(HTTPURLResponse?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz URL"
        case .httpError(let response):
            return "HTTP Hatası: \(response?.statusCode ?? 0)"
        }
    }
} 