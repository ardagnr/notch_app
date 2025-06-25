import Foundation

enum NotchMenuOption: String, CaseIterable {
    case gemini = "Gemini AI"
    case timer = "Sayaç"
    case notes = "Notlar"
    
    var icon: String {
        switch self {
        case .gemini:
            return "sparkles"
        case .timer:
            return "timer"
        case .notes:
            return "note.text"
        }
    }
    
    var description: String {
        switch self {
        case .gemini:
            return "AI ile sohbet et"
        case .timer:
            return "Sayaç başlat"
        case .notes:
            return "Notlarını görüntüle"
        }
    }
} 