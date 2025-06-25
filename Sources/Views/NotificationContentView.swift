import SwiftUI

/// Bildirim verilerini içeren yapı
struct NotificationData {
    let title: String
    let subtitle: String
    let body: String
    let appName: String
    let appBundleId: String?
    let timestamp: Date
    
    init(title: String = "", subtitle: String = "", body: String = "", appName: String = "", appBundleId: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.appName = appName
        self.appBundleId = appBundleId
        self.timestamp = Date()
    }
}

/// Bildirim içeriğini gösteren SwiftUI view
struct NotificationContentView: View {
    let notification: NotificationData
    
    private var appIconColor: Color {
        switch notification.appName.lowercased() {
        case let name where name.contains("whatsapp"):
            return Color(red: 0.13, green: 0.66, blue: 0.31) // WhatsApp yeşili
        case let name where name.contains("telegram"):
            return Color(red: 0.21, green: 0.67, blue: 0.90) // Telegram mavisi
        case let name where name.contains("slack"):
            return Color(red: 0.44, green: 0.18, blue: 0.54) // Slack moru
        case let name where name.contains("discord"):
            return Color(red: 0.35, green: 0.40, blue: 0.90) // Discord moru
        case let name where name.contains("mail"):
            return Color(red: 0.00, green: 0.48, blue: 1.00) // Mail mavisi
        case let name where name.contains("messages"):
            return Color(red: 0.20, green: 0.78, blue: 0.35) // Messages yeşili
        default:
            return Color.gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Sol: Sadece uygulama ikonu (orta boy)
            getAppIcon()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
            
            // Sağ: Mesaj içeriği
            VStack(alignment: .leading, spacing: 3) {
                // Üst kısım: Gönderen adı ve zaman
                HStack {
                    Text(getContactName())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                // Alt kısım: Mesaj içeriği
                Text(getMessageContent())
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(width: getDynamicWidth(), alignment: .leading) // Dinamik genişlik
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.92))
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        )
    }
    
    private func getContactName() -> String {
        // Eğer title'da ":" varsa, bundan önceki kısım kişi adı
        if !notification.title.isEmpty, notification.title != "WhatsApp" {
            if let colonIndex = notification.title.firstIndex(of: ":") {
                let contactName = String(notification.title[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                return contactName.isEmpty ? "WhatsApp" : contactName
            }
            return notification.title
        }
        return "WhatsApp"
    }
    
    private func getMessageContent() -> String {
        // Eğer body boş değilse body'yi kullan
        if !notification.body.isEmpty {
            return notification.body
        }
        
        // Eğer title'da ":" varsa, bundan sonraki kısım mesaj olabilir
        if !notification.title.isEmpty, let colonIndex = notification.title.firstIndex(of: ":") {
            let messageContent = String(notification.title[notification.title.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            if !messageContent.isEmpty {
                return messageContent
            }
        }
        
        // Eğer title varsa ve "WhatsApp" değilse onu kullan
        if !notification.title.isEmpty && notification.title != "WhatsApp" {
            return notification.title
        }
        
        return "You have a new message"
    }
    
    // Removed unused getContactInitials() and getContactColor() functions
    
    @ViewBuilder
    private func getAppIcon() -> some View {
        if let appIcon = getAppIconImage() {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Fallback: Renkli placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(appIconColor)
                .overlay(
                    Group {
                        if notification.appName.localizedCaseInsensitiveContains("whatsapp") {
                            Text("W")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        } else if notification.appName.localizedCaseInsensitiveContains("telegram") {
                            Text("T")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        } else if notification.appName.localizedCaseInsensitiveContains("slack") {
                            Text("S")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        } else if notification.appName.localizedCaseInsensitiveContains("discord") {
                            Text("D")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text(notification.appName.prefix(1).uppercased())
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
        }
    }
    
    private func getAppIconImage() -> NSImage? {
        // Bundle ID'den gerçek uygulama ikonunu al
        let bundleId = notification.appBundleId ?? getBundleIdFromAppName()
        
        guard !bundleId.isEmpty else { return nil }
        
        // NSWorkspace ile uygulama ikonunu al
        let workspace = NSWorkspace.shared
        
        // Bundle ID'den uygulama path'ini bul
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            return workspace.icon(forFile: appURL.path)
        }
        
        // Alternatif: Çalışan uygulamalardan bul
        let runningApps = workspace.runningApplications
        for app in runningApps {
            if app.bundleIdentifier == bundleId {
                return app.icon
            }
        }
        
        return nil
    }
    
    private func getBundleIdFromAppName() -> String {
        switch notification.appName.lowercased() {
        case let name where name.contains("whatsapp"):
            return "net.whatsapp.WhatsApp"
        case let name where name.contains("telegram"):
            return "org.telegram.desktop"
        case let name where name.contains("slack"):
            return "com.tinyspeck.slackmacgap"
        case let name where name.contains("discord"):
            return "com.discordapp.Discord"
        case let name where name.contains("mail"):
            return "com.apple.mail"
        case let name where name.contains("messages"):
            return "com.apple.MobileSMS"
        default:
            return ""
        }
    }
    
    private func getDynamicWidth() -> CGFloat {
        let messageContent = getMessageContent()
        let contactName = getContactName()
        
        // Temel genişlik (ikon + padding + minimum alan)
        let baseWidth: CGFloat = 200
        
        // Mesaj içeriği uzunluğuna göre ek genişlik hesapla
        let messageLength = messageContent.count
        let nameLength = contactName.count
        
        // Karakter başına genişlik faktörü
        let charWidthFactor: CGFloat = 7.5
        
        // En uzun metin (isim veya mesaj) göz önünde bulundur
        let maxTextLength = max(messageLength, nameLength)
        
        // Dinamik genişlik hesapla
        var dynamicWidth = baseWidth + (CGFloat(maxTextLength) * charWidthFactor)
        
        // Minimum ve maksimum sınırlar
        let minWidth: CGFloat = 280  // En az bu kadar geniş
        let maxWidth: CGFloat = 650  // En fazla bu kadar geniş
        
        dynamicWidth = max(minWidth, min(maxWidth, dynamicWidth))
        
        // Mesaj satır sayısına göre ek ayarlama
        if messageContent.count > 50 {
            dynamicWidth += 30 // Uzun mesajlar için ek genişlik
        }
        
        if messageContent.count > 80 {
            dynamicWidth += 40 // Çok uzun mesajlar için daha da fazla
        }
        
        return dynamicWidth
    }
}



#Preview {
    NotificationContentView(
        notification: NotificationData(
            title: "Annem",
            subtitle: "",
            body: "Merhaba nasılsın? Bu akşam yemeğe gelir misin?",
            appName: "WhatsApp",
            appBundleId: "net.whatsapp.WhatsApp"
        )
    )
    .preferredColorScheme(.dark)
    .padding()
} 