import Cocoa
import SwiftUI
import ApplicationServices
import DynamicNotchKit

/// macOS bildirimlerini yakalayan ve çentikte gösteren controller
class NotificationController: ObservableObject {
    
    // MARK: - Properties
    @Published var latestNotification: NotificationData?
    @Published var isShowingNotification = false
    
    private var observer: AXObserver?
    private var systemWideElement: AXUIElement?
    private var notificationNotch: DynamicNotch<NotificationContentView, EmptyView, EmptyView>?
    
    // Performans için debounce timer
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.5
    
    // Bildirim gösterim süresi (saniye)
    private let notificationDisplayDuration: TimeInterval = 5.0
    
    // Debug kontrolü sınıftan çıkarıldı - global tanımlandı
    
    // MARK: - Initialization
    init() {
        setupAccessibilityPermissions()
        setupWorkspaceObserver()
        setupDistributedNotificationObserver()
    }
    
    deinit {
        // Observer'ları temizle
        if let observer = observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                CFRunLoopMode.defaultMode
            )
        }
        
        debounceTimer?.invalidate()
        
        // Workspace observer'ları temizle
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
    }
    
    // MARK: - Accessibility Permissions
    private func setupAccessibilityPermissions() {
        // Accessibility izinlerini kontrol et
        let trusted = AXIsProcessTrusted()
        debugLog("🔒 Accessibility permissions trusted: \(trusted)")
        
        if !trusted {
            print("🔑 Requesting accessibility permissions...")
            // İzin iste
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            let _ = AXIsProcessTrustedWithOptions(options)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.checkAndStartMonitoring()
            }
        } else {
            print("✅ Accessibility permissions already granted")
            startMonitoring()
        }
    }
    
    private func checkAndStartMonitoring() {
        if AXIsProcessTrusted() {
            startMonitoring()
        } else {
            print("⚠️ Accessibility permissions required for notification monitoring")
        }
    }
    
    // Debug helper fonksiyonları global tanımlandı
    
    // MARK: - Monitoring
    func startMonitoring() {
        guard AXIsProcessTrusted() else {
            print("❌ Accessibility permissions not granted")
            return
        }
        
        setupAXObserver()
        print("✅ Notification monitoring started")
    }
    
    @MainActor
    func stopMonitoring() {
        if let observer = observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                CFRunLoopMode.defaultMode
            )
        }
        
        observer = nil
        systemWideElement = nil
        debounceTimer?.invalidate()
        debounceTimer = nil
        
        // Workspace observer'ları temizle
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        // Distributed notification observer'ları temizle
        DistributedNotificationCenter.default.removeObserver(self)
        
        print("🛑 Notification monitoring stopped")
    }
    
    private func setupAXObserver() {
        debugLog("🔧 Setting up AXObserver with simplified approach...")
        
        // Her çalışan uygulama için observer kur
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            if let bundleId = app.bundleIdentifier,
               let pid = app.processIdentifier as pid_t?,
               pid > 0 {
                
                // Sadece bildirim uygulamaları için observer kur
                let notificationApps = [
                    "net.whatsapp.WhatsApp",
                    "com.tinyspeck.slackmacgap",
                    "org.telegram.desktop",
                    "com.discordapp.Discord",
                    "com.apple.mail",
                    "com.apple.MobileSMS",
                    "com.apple.notificationcenterui",
                    "com.apple.UserNotificationCenter"
                ]
                
                if notificationApps.contains(bundleId) {
                    setupObserverForApp(pid: pid, bundleId: bundleId)
                }
            }
        }
    }
    
    private func setupObserverForApp(pid: pid_t, bundleId: String) {
        debugLog("🔧 Setting up observer for \(bundleId) (PID: \(pid))")
        
        let appElement = AXUIElementCreateApplication(pid)
        
        // Bu app için observer oluştur
        var observer: AXObserver?
        let result = AXObserverCreate(pid, axObserverCallback, &observer)
        
        guard result == .success, let observer = observer else {
            debugLog("⚠️ Could not create observer for \(bundleId): \(result.rawValue)")
            return
        }
        
        // Store the first observer (we'll use it for all)
        if self.observer == nil {
            self.observer = observer
            
            // Observer'ı run loop'a ekle
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                CFRunLoopMode.defaultMode
            )
        }
        
        // Event'leri ekle
        let addResult = AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, nil)
        if addResult == .success {
            print("✅ Successfully added window observer for: \(bundleId)")
        } else {
            debugLog("⚠️ Failed to add window observer for \(bundleId): \(addResult.rawValue)")
        }
    }
    

}

// MARK: - AX Observer Callback
private func axObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    userData: UnsafeMutableRawPointer?
) {
    // Sadece kritik event'leri logla
    let notificationName = notification as String
    
    // Tüm ilgili event'leri işle
    if notificationName == kAXWindowCreatedNotification || 
       notificationName == kAXApplicationActivatedNotification ||
       notificationName == kAXCreatedNotification ||
       notificationName == kAXFocusedWindowChangedNotification {
        
        // Ana thread'de işle
        DispatchQueue.main.async {
            processNotificationElement(element)
        }
    }
}

// Global debug functions
private let debugMode: Bool = false
private let verboseMode: Bool = false

private func debugLog(_ message: String) {
    if debugMode {
        print(message)
    }
}

private func verboseLog(_ message: String) {
    if verboseMode {
        print(message)
    }
}

private func processNotificationElement(_ element: AXUIElement) {
    // Element'in bir bildirim olup olmadığını kontrol et
    let isNotification = isNotificationElement(element)
    
    if isNotification {
        // Bildirim içeriğini çıkar
        if let notificationData = extractNotificationData(from: element) {
            print("📨 Notification received: \(notificationData.appName) - \(notificationData.title)")
            NotificationCenter.default.post(
                name: .notificationReceived,
                object: notificationData
            )
        }
    }
}

private func isNotificationElement(_ element: AXUIElement) -> Bool {
    // Role kontrolü
    var roleValue: CFTypeRef?
    let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
    
    guard roleResult == .success,
          let role = roleValue as? String else { return false }
    
    // Farklı türde bildirim pencerelerini kontrol et
    if role == kAXWindowRole || role == "AXNotification" || role == "AXBanner" {
        // Subrole kontrolü
        var subroleValue: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue)
        
        if subroleResult == .success,
           let subrole = subroleValue as? String {
            verboseLog("🏷️ Element subrole: \(subrole)")
            // Sistem bildirim pencereleri
            if subrole == kAXSystemDialogSubrole || 
               subrole == kAXFloatingWindowSubrole ||
               subrole == "AXNotificationCenterBanner" ||
               subrole.contains("Banner") ||
               subrole.contains("Notification") {
                debugLog("🎯 Found notification by subrole: \(subrole)")
                return true
            }
        }
        
        // Window title kontrolü
        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        
        if titleResult == .success,
           let title = titleValue as? String {
            verboseLog("📝 Checking title: '\(title)'")
            
            // Ana WhatsApp penceresi değilse ve WhatsApp içeriyorsa
            if title.localizedCaseInsensitiveContains("whatsapp") && title != "‎WhatsApp" {
                debugLog("🎯 Found WhatsApp notification window: '\(title)'")
                return true
            }
            
            // Bildirim içeriği bulunan title'lar
            if title.contains(":") || title.contains("New message") || 
               title.localizedCaseInsensitiveContains("message") ||
               title.localizedCaseInsensitiveContains("notification") {
                debugLog("🎯 Found notification by content pattern: '\(title)'")
                return true
            }
        }
        
        // Window position kontrolü - bildirimler genelde ekranın üst kısmında
        var positionValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
           let positionData = positionValue {
            var point = CGPoint.zero
            let success = AXValueGetValue(positionData as! AXValue, .cgPoint, &point)
            
            if success {
                verboseLog("📍 Element position: \(point)")
                
                // Ekranın üst 300 piksel alanında olan pencereler bildirim olabilir (daha esnek)
                if point.y < 300 {
                    // Size kontrolü - bildirimler genelde küçük ve yatay
                    var sizeValue: CFTypeRef?
                    if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
                       let sizeData = sizeValue {
                        var size = CGSize.zero
                        let sizeSuccess = AXValueGetValue(sizeData as! AXValue, .cgSize, &size)
                        
                        if sizeSuccess {
                            verboseLog("📏 Element size: \(size)")
                            // Bildirim boyutları (daha esnek aralık)
                            if size.width > 150 && size.width < 600 && 
                               size.height > 30 && size.height < 200 {
                                debugLog("🎯 Found notification by position/size")
                                return true
                            }
                        }
                    }
                } else if point.y >= 0 && point.y < 600 {
                    // Bildirimlerin farklı pozisyonlarda da olabileceğini düşün
                    verboseLog("🔍 Element in potential notification area")
                    
                    // Title'da bildirim ipucu var mı kontrol et
                    var titleValue: CFTypeRef?
                    let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
                    if titleResult == .success, let title = titleValue as? String {
                        if title.localizedCaseInsensitiveContains("whatsapp") ||
                           title.localizedCaseInsensitiveContains("message") ||
                           title.localizedCaseInsensitiveContains("notification") {
                            debugLog("🎯 Found notification by alternative position + title")
                            return true
                        }
                    }
                }
            }
        }
    }
    
    return false
}

private func extractNotificationData(from element: AXUIElement) -> NotificationData? {
    var title = ""
    var body = ""
    var appName = ""
    
    verboseLog("🔍 Starting deep notification content extraction...")
    
    // Önce element'in title'ını kontrol et
    var elementTitleValue: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &elementTitleValue) == .success,
       let elementTitle = elementTitleValue as? String {
        verboseLog("📋 Main element title: '\(elementTitle)'")
        if elementTitle != "Notification Center" {
            title = elementTitle
        }
    }
    
    // Çocuk elementleri tara - tüm seviyeler
    func extractFromChildren(_ parent: AXUIElement, depth: Int = 0) {
        guard depth < 5 else { return } // Maksimum 5 seviye derinlik
        
        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &childrenValue)
        
        guard childrenResult == .success,
              let children = childrenValue as? [AXUIElement] else { return }
        
        verboseLog("🔍 Level \(depth): Found \(children.count) children")
        
        for (index, child) in children.enumerated() {
            guard index < 20 else { break } // Maksimum 20 çocuk kontrol et
            
            // Role kontrol et
            var roleValue: CFTypeRef?
            let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)
            
            if roleResult == .success, let role = roleValue as? String {
                verboseLog("📋 Child \(index) role: \(role)")
                
                // Tüm possible attribute'ları kontrol et
                func extractAllPossibleText(from element: AXUIElement) {
                    let attributesToCheck = [
                        kAXValueAttribute,
                        kAXTitleAttribute,
                        kAXDescriptionAttribute,
                        kAXHelpAttribute,
                        "AXLabel"
                    ]
                    
                    for attribute in attributesToCheck {
                        var result: CFTypeRef?
                                                if AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success,
                           let text = result as? String, !text.isEmpty && text != "Notification Center" {
                            verboseLog("📝 Found text from \(attribute): '\(text)'")
                             
                             // macOS sistem metinlerini filtrele
                             let systemTexts = [
                                 "Bildirimleri Sil", "Bildirimleri Sil…", "Clear All", "Options",
                                 "Notification Center", "Show More", "Show Less", "Close"
                             ]
                             
                             let isSystemText = systemTexts.contains { systemText in
                                 text.localizedCaseInsensitiveContains(systemText)
                             }
                             
                             if isSystemText {
                                 verboseLog("🚫 Skipping system text: '\(text)'")
                                 continue
                             }
                             
                             // WhatsApp style description parsing (örn: "WhatsApp, Annem, Deneme 7")
                             if text.contains(",") && text.localizedCaseInsensitiveContains("whatsapp") {
                                 let parts = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                                 if parts.count >= 3 {
                                     // parts[0] = "WhatsApp", parts[1] = "Annem", parts[2] = "Deneme 7"
                                     appName = parts[0]
                                     if title.isEmpty {
                                         title = parts[1] // Gönderen kişi
                                     }
                                     if body.isEmpty {
                                         body = parts[2] // Mesaj içeriği
                                     }
                                     debugLog("🎯 Parsed WhatsApp format - App: '\(parts[0])', Sender: '\(parts[1])', Message: '\(parts[2])'")
                                 }
                             }
                             // WhatsApp ve diğer app isimleri
                             else if text.localizedCaseInsensitiveContains("whatsapp") ||
                                    text.localizedCaseInsensitiveContains("telegram") ||
                                    text.localizedCaseInsensitiveContains("slack") {
                                 if appName.isEmpty {
                                     appName = text
                                 }
                             }
                             // Kişi adları (genelde kısa, özel karakterler içermez)
                             else if text.count > 1 && text.count <= 20 && !text.contains(" ") && title.isEmpty {
                                 title = text
                                 verboseLog("🧑 Found contact name: '\(text)'")
                             }
                             // Mesaj içeriği (orta uzunlukta metinler)
                             else if text.count > 1 && text.count <= 100 && body.isEmpty && !title.isEmpty {
                                 body = text
                                 verboseLog("💬 Found message content: '\(text)'")
                             }
                             // Uzun metinler muhtemelen içerik
                             else if text.count > 10 && body.isEmpty {
                                 body = text
                                 verboseLog("📝 Found long content: '\(text)'")
                             }
                        }
                    }
                }
                
                // Hemen tüm attribute'ları kontrol et
                extractAllPossibleText(from: child)
                
                // Eğer ScrollArea ise özel olarak content'ini kontrol et
                if role == "AXScrollArea" {
                    verboseLog("🔍 Special handling for AXScrollArea")
                    
                    // ScrollArea'nın içindeki content'i kontrol et
                    var contentsValue: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, "AXContents" as CFString, &contentsValue) == .success,
                       let contents = contentsValue as? [AXUIElement] {
                        verboseLog("📜 ScrollArea has \(contents.count) contents")
                        for content in contents.prefix(10) {
                            extractAllPossibleText(from: content)
                            extractFromChildren(content, depth: depth + 1)
                        }
                    }
                    
                    // Alternatif olarak, VerticalScrollBar ve HorizontalScrollBar'ı da kontrol et
                    let scrollAttributes = [
                        "AXVerticalScrollBar",
                        "AXHorizontalScrollBar",
                        "AXRows",
                        "AXColumns"
                    ]
                    
                    for scrollAttr in scrollAttributes {
                        var scrollResult: CFTypeRef?
                        if AXUIElementCopyAttributeValue(child, scrollAttr as CFString, &scrollResult) == .success {
                            verboseLog("📜 Found scroll attribute: \(scrollAttr)")
                            if let scrollElements = scrollResult as? [AXUIElement] {
                                for scrollElement in scrollElements.prefix(5) {
                                    extractAllPossibleText(from: scrollElement)
                                    extractFromChildren(scrollElement, depth: depth + 1)
                                }
                            }
                        }
                    }
                }
                
                // Her türlü container'a gir
                if role == kAXGroupRole || role == kAXButtonRole || role == "AXLayoutArea" || 
                   role == "AXScrollArea" || role == kAXListRole || role == kAXTableRole {
                    extractFromChildren(child, depth: depth + 1)
                }
            }
        }
    }
    
    // Extraction başlat
    extractFromChildren(element)
    
    debugLog("🔍 Extraction complete - Title: '\(title)', Body: '\(body)', App: '\(appName)'")
    
    // Eğer hiçbir şey bulunamadıysa, default WhatsApp bilgisi ver (çünkü WhatsApp bildirimi yakalandı)
    if title.isEmpty && body.isEmpty && appName.isEmpty {
        print("🔄 No content found, creating default notification")
        return NotificationData(
            title: "WhatsApp",
            subtitle: "",
            body: "You have a new message",
            appName: "WhatsApp",
            appBundleId: "net.whatsapp.WhatsApp"
        )
    }
    
    // Eğer anlamlı veri varsa NotificationData oluştur
    if !title.isEmpty || !body.isEmpty {
        return NotificationData(
            title: title.isEmpty ? "Notification" : title,
            subtitle: "",
            body: body,
            appName: appName.isEmpty ? "WhatsApp" : appName,
            appBundleId: appName.localizedCaseInsensitiveContains("whatsapp") ? "net.whatsapp.WhatsApp" : nil
        )
    }
    
    return nil
}

// MARK: - Extensions
extension NotificationController {
    func showNotification(_ notification: NotificationData) {
        latestNotification = notification
        
        // Debounce timer - performans için
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { _ in
            DispatchQueue.main.async {
                self.displayNotificationInNotch()
            }
        }
    }
    
    private func displayNotificationInNotch() {
        guard let notification = latestNotification else { return }
        
        // Önceki notch'u gizle
        Task { @MainActor in
            // Önceki bildirimi varsa hızlıca gizle
            if isShowingNotification {
                await notificationNotch?.hide()
                try? await Task.sleep(for: .seconds(0.2))
            }
            
            // Yeni notch oluştur
            notificationNotch = DynamicNotch(
                hoverBehavior: [.keepVisible, .hapticFeedback],
                style: .auto
            ) {
                NotificationContentView(notification: notification)
            }
            
            // Notch'u göster
            await notificationNotch?.expand()
            
            // Belirlenen süre sonra gizle
            try? await Task.sleep(for: .seconds(notificationDisplayDuration))
            
            // Hala aynı bildirim gösteriliyorsa gizle
            if self.latestNotification?.timestamp == notification.timestamp {
                await notificationNotch?.hide()
                
                // State'i güncelle
                self.isShowingNotification = false
            }
        }
        
        isShowingNotification = true
        debugLog("📱 Displaying notification: \(notification.appName) - \(notification.title)")
    }
    
    // MARK: - Workspace Observer
    private func setupWorkspaceObserver() {
        // NSWorkspace ile uygulama aktivasyonlarını dinle
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleApplicationActivation(notification)
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleApplicationLaunch(notification)
            }
        }
    }
    
    @MainActor
    private func handleApplicationActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        
        // Bilinen bildirim uygulamaları
        let notificationApps = [
            "com.tinyspeck.slackmacgap", // Slack
            "net.whatsapp.WhatsApp", // WhatsApp
            "org.telegram.desktop", // Telegram
            "com.discordapp.Discord", // Discord
            "com.apple.mail", // Mail
            "com.apple.MobileSMS" // Messages
        ]
        
        if let bundleId = app.bundleIdentifier,
           notificationApps.contains(bundleId) {
            print("📱 Notification app activated: \(app.localizedName ?? bundleId)")
            
            // WhatsApp simülasyonunu kaldırdık - sadece gerçek bildirimleri istiyoruz
            
            // Kısa bir gecikme sonra bu uygulamanın pencerelerini kontrol et
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.checkForNotificationWindows(from: app)
            }
        }
    }
    
    
     
     // MARK: - Distributed Notifications
     private func setupDistributedNotificationObserver() {
         // macOS sistem bildirimlerini dinle
         let distributedCenter = DistributedNotificationCenter.default
         
         let notificationNames = [
             "com.apple.coredata.ubiquity.ubiquitous_content_updated",
             "com.apple.UserNotificationCenter.notification-posted",
             "com.apple.UserNotificationCenter.notification-received",
             "NSUserNotificationDidActivate",
             "NSUserNotificationDidDeliverNotification",
             "AppleShowAllNotifications",
             "AppleHideAllNotifications"
         ]
         
         for name in notificationNames {
             distributedCenter.addObserver(
                 forName: NSNotification.Name(name),
                 object: nil,
                 queue: .main
             ) { [weak self] notification in
                 if let notification = notification as? NSNotification {
                     self?.handleDistributedNotification(notification)
                 }
             }
         }
         
         debugLog("🔔 Distributed notification observers set up")
     }
     
     private func handleDistributedNotification(_ notification: NSNotification) {
         debugLog("📩 Processing distributed notification: \(notification.name.rawValue)")
         
         if let userInfo = notification.userInfo {
             verboseLog("📋 UserInfo: \(userInfo)")
         }
         
         // Basit bildirim oluştur
         let notificationData = NotificationData(
             title: "System Notification",
             subtitle: "",
             body: "A system notification was detected",
             appName: "System",
             appBundleId: nil
         )
         
         showNotification(notificationData)
     }
     
     @MainActor
    private func handleApplicationLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        
        if let bundleId = app.bundleIdentifier,
           bundleId.contains("notification") || bundleId.contains("Notification") {
            debugLog("🚀 Notification-related app launched: \(app.localizedName ?? bundleId)")
        }
    }
    
    private func checkForNotificationWindows(from app: NSRunningApplication) {
        guard let pid = app.processIdentifier as pid_t?,
              pid > 0 else { return }
        
        let appElement = AXUIElementCreateApplication(pid)
        
        // App'in pencerelerini al
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        
        guard result == .success,
              let windows = windowsValue as? [AXUIElement] else { return }
        
        // Her pencereyi kontrol et
        for window in windows.prefix(5) { // Performans için maksimum 5 pencere
            if isNotificationElement(window) {
                if let notification = extractNotificationData(from: window) {
                    DispatchQueue.main.async {
                        self.showNotification(notification)
                    }
                }
            }
        }
    }
}

// MARK: - Notification Extensions
extension NSNotification.Name {
    static let notificationReceived = NSNotification.Name("notificationReceived")
}

// NotificationContentView artık ayrı bir dosyada tanımlı