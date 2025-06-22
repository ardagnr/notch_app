import Foundation
import SwiftUI
import DynamicNotchKit

class NotchHoverController: ObservableObject {
    @Published var isHovering = false
    @Published var isGeminiChatVisible = false
    
    private var hoverDetectionTimer: Timer?
    private var geminiNotch: DynamicNotch<AnyView, EmptyView, EmptyView>?
    private let geminiController = GeminiController()
    private var hoverStartTime: Date?
    private var exitStartTime: Date?
    
    // Weak reference to media controller to check if music is playing
    weak var mediaController: MediaController?
    
    init(mediaController: MediaController? = nil) {
        self.mediaController = mediaController
        startHoverDetection()
    }
    
    private func startHoverDetection() {
        // Real-time hover detection için Timer gerekli (Background scheduler çok yavaş)
        hoverDetectionTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
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
        let notchWidth: CGFloat = 400  // Çentik genişliği
        let notchHeight: CGFloat = 50  // Çentik yüksekliği
        
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
            await self.showGeminiChatWindow()
        }
    }
    
    private func handleMouseExit() {
        hideGeminiChat()
    }
    
    @MainActor
    private func showGeminiChatWindow() async {
        // Eğer zaten gösteriliyorsa, tekrar gösterme
        guard geminiNotch == nil else { return }
        
        let chatView = GeminiChatView(geminiController: geminiController)
        
        geminiNotch = DynamicNotch(
            hoverBehavior: [.keepVisible],
            style: .notch(topCornerRadius: 15, bottomCornerRadius: 20)
        ) {
            AnyView(chatView)
        }
        
        await geminiNotch?.expand()
        
        isGeminiChatVisible = true
    }
    
    private func hideGeminiChat() {
        guard let notch = geminiNotch else { return }
        
        Task {
            await notch.hide()
            await MainActor.run {
                self.geminiNotch = nil
                self.isGeminiChatVisible = false
            }
        }
    }
    
    func stopHoverDetection() {
        hoverDetectionTimer?.invalidate()
        hoverDetectionTimer = nil
        hideGeminiChat()
    }
    
    // Test function to manually show Gemini chat
    func forceShowGeminiChat() {
        Task { @MainActor in
            await self.showGeminiChatWindow()
        }
    }
    
    deinit {
        stopHoverDetection()
    }
} 