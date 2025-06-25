import Foundation
import SwiftUI
import DynamicNotchKit

class NotchHoverController: ObservableObject {
    @Published var isHovering = false
    @Published var activeNotchType: NotchMenuOption?
    
    private var hoverDetectionTimer: Timer?
    private var activeNotch: DynamicNotch<AnyView, EmptyView, EmptyView>?
    
    // Controllers for different notch types
    private let geminiController = GeminiController()
    private let timerController = TimerController()
    private let notesController = NotesController()
    
    private var hoverStartTime: Date?
    private var exitStartTime: Date?
    
    // UserDefaults key for remembering last used notch
    private let lastUsedNotchKey = "LastUsedNotchType"
    
    // Weak reference to media controller to check if music is playing
    weak var mediaController: MediaController?
    
    init(mediaController: MediaController? = nil) {
        self.mediaController = mediaController
        startHoverDetection()
    }
    
    private func startHoverDetection() {
        // Real-time hover detection için Timer gerekli (Background scheduler çok yavaş)
        hoverDetectionTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Sadece Spotify track yoksa hover kontrolü yap - enerji tasarrufu
            if let mediaController = self.mediaController,
               mediaController.currentTrack != nil {
                return
            }
            
            self.checkMousePosition()
        }
    }
    
    private func checkMousePosition() {
        guard let screen = NSScreen.main else { return }
        
        // Mouse pozisyonunu al
        let mouseLocation = NSEvent.mouseLocation
        
        // Notch bölgesini tanımla
        let notchArea = getNotchArea(for: screen)
        
        // Mouse notch bölgesinde mi kontrol et
        let isCurrentlyHovering = notchArea.contains(mouseLocation)
        
        // Hover delay logic
        if isCurrentlyHovering && !isHovering {
            // Mouse entered
            if hoverStartTime == nil {
                hoverStartTime = Date()
            } else if Date().timeIntervalSince(hoverStartTime!) > 0.5 {
                // 0.5 saniye bekle
                DispatchQueue.main.async {
                    self.isHovering = true
                    self.handleMouseEnter()
                    self.hoverStartTime = nil
                    self.exitStartTime = nil
                }
            }
        } else if !isCurrentlyHovering && isHovering {
            // Mouse exited
            if exitStartTime == nil {
                exitStartTime = Date()
            } else if Date().timeIntervalSince(exitStartTime!) > 0.3 {
                // 0.3 saniye bekle
                DispatchQueue.main.async {
                    self.isHovering = false
                    self.handleMouseExit()
                    self.hoverStartTime = nil
                    self.exitStartTime = nil
                }
            }
        } else if !isCurrentlyHovering {
            // Reset timers if not hovering
            hoverStartTime = nil
            exitStartTime = nil
        }
    }
    
    private func getNotchArea(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        
        // Çentik bölgesini hesapla (ekranın üst ortasında)
        // Notch açıkken alanı büyüt, kapalıyken küçük tut
        let notchWidth: CGFloat = activeNotch != nil ? 400 : 400
        let notchHeight: CGFloat = activeNotch != nil ? 450 : 50  // Açıkken büyük alan
        
        let notchX = (screenFrame.width - notchWidth) / 2
        let notchY = screenFrame.height - notchHeight
        
        return NSRect(
            x: screenFrame.origin.x + notchX,
            y: screenFrame.origin.y + notchY,
            width: notchWidth,
            height: notchHeight
        )
    }
    
    private func handleMouseEnter() {
        // Spotify açık ve müzik var mı kontrol et
        if let mediaController = mediaController {
            let spotifyActive = mediaController.currentTrack != nil
            
            if spotifyActive {
                return
            }
        }
        
        Task { @MainActor in
            await self.showLastUsedNotch()
        }
    }
    
    private func handleMouseExit() {
        hideActiveNotch()
    }
    
    @MainActor
    private func showLastUsedNotch() async {
        // Son kullanılan çentik tipini al, yoksa Gemini'yi default olarak kullan
        let lastUsedRawValue = UserDefaults.standard.string(forKey: lastUsedNotchKey) ?? NotchMenuOption.gemini.rawValue
        let lastUsedOption = NotchMenuOption.allCases.first { $0.rawValue == lastUsedRawValue } ?? .gemini
        
        await showNotchForOption(lastUsedOption)
    }
    
    @MainActor
    private func handleMenuSelection(_ option: NotchMenuOption) async {
        print("🎯 Menu option selected: \(option.rawValue)")
        
        // Show selected notch type
        await showNotchForOption(option)
    }
    
    @MainActor
    private func showNotchForOption(_ option: NotchMenuOption) async {
        // Eğer zaten bir notch açıksa, önce onu kapat
        if activeNotch != nil {
            await forceHideActiveNotch()
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 saniye bekle
        }
        
        // Son kullanılan çentik tipini kaydet
        UserDefaults.standard.set(option.rawValue, forKey: lastUsedNotchKey)
        
        let contentView: AnyView
        
        switch option {
        case .gemini:
            let geminiView = GeminiChatView(
                geminiController: geminiController,
                onMenuSelection: { [weak self] newOption in
                    Task { @MainActor in
                        await self?.handleMenuSelection(newOption)
                    }
                }
            )
            contentView = AnyView(geminiView)
            
        case .timer:
            let timerView = TimerNotchView(
                timerController: timerController,
                onMenuSelection: { [weak self] newOption in
                    Task { @MainActor in
                        await self?.handleMenuSelection(newOption)
                    }
                }
            )
            contentView = AnyView(timerView)
            
        case .notes:
            let notesView = NotesNotchView(
                notesController: notesController,
                onMenuSelection: { [weak self] newOption in
                    Task { @MainActor in
                        await self?.handleMenuSelection(newOption)
                    }
                }
            )
            contentView = AnyView(notesView)
        }
        
        activeNotch = DynamicNotch(
            hoverBehavior: [], // Hover behavior'u kapat - manuel kontrol kullanacağız
            style: .notch(topCornerRadius: 15, bottomCornerRadius: 20)
        ) {
            contentView
        }
        
        await activeNotch?.expand()
        activeNotchType = option
        
        // Not needed anymore - using manual hover detection
        
        print("✅ Showing \(option.rawValue) notch")
    }
    
    private func hideActiveNotch() {
        guard let notch = activeNotch else { return }
        
        Task {
            await notch.hide()
            await MainActor.run {
                self.activeNotch = nil
                self.activeNotchType = nil
            }
        }
    }
    
    // Notch'u force olarak kapat (menü değişimi için)
    @MainActor
    private func forceHideActiveNotch() async {
        guard let notch = activeNotch else { return }
        
        await notch.hide()
        self.activeNotch = nil
        self.activeNotchType = nil
    }
    
    func stopHoverDetection() {
        hoverDetectionTimer?.invalidate()
        hoverDetectionTimer = nil
        hideActiveNotch()
    }
    
    // Test function to manually show last used notch
    func forceShowLastUsed() {
        Task { @MainActor in
            await self.showLastUsedNotch()
        }
    }
    
    // Direct access functions for testing specific notches
    func forceShowGeminiChat() {
        Task { @MainActor in
            await self.showNotchForOption(.gemini)
        }
    }
    
    func forceShowTimer() {
        Task { @MainActor in
            await self.showNotchForOption(.timer)
        }
    }
    
    func forceShowNotes() {
        Task { @MainActor in
            await self.showNotchForOption(.notes)
        }
    }
    
    private func monitorNotchHoverState() {
        // DynamicNotch'un built-in hover sistemi kullanacağız
        // Sadece bir delay ekleyerek hover'dan çıktıktan sonra kapanacak
        print("📱 Monitoring notch hover state with built-in system")
    }
    
    deinit {
        stopHoverDetection()
    }
} 