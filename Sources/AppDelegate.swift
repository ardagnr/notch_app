import Cocoa
import SwiftUI
import MediaPlayer
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mediaController: MediaController?
    private var volumeController: VolumeController?
    private var notchHoverController: NotchHoverController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Performance optimizations for background app
        ProcessInfo.processInfo.disableSuddenTermination()
        
        // App Nap desteği - sistem enerji yönetimini etkinleştir
        ProcessInfo.processInfo.enableSuddenTermination()
        
        // Quality of Service ayarları
        DispatchQueue.global(qos: .utility).async {
            // Background işlemler için düşük öncelik
        }
        
        // Create status bar item
        setupStatusBarItem()
        
        // Initialize controllers
        setupControllers()
        
        // Request permissions
        requestPermissions()
        

    }
    

    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NotchApp")
        }
        
        // Create menu
        let menu = NSMenu()
        
        // Test Gemini Chat
        let geminiTest = NSMenuItem(title: "🤖 Test Gemini Chat", action: #selector(testGeminiChat), keyEquivalent: "")
        geminiTest.target = self
        menu.addItem(geminiTest)
        
        menu.addItem(NSMenuItem.separator())
        
        // Test volume
        let volumeItem = NSMenuItem(title: "🔊 Test Volume", action: #selector(testVolume), keyEquivalent: "")
        volumeItem.target = self
        menu.addItem(volumeItem)
        
        // Force media update
        let mediaUpdateItem = NSMenuItem(title: "🎵 Force Media Update", action: #selector(forceMediaUpdate), keyEquivalent: "")
        mediaUpdateItem.target = self
        menu.addItem(mediaUpdateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(statusItemClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    private func setupControllers() {
        print("🏗️ Setting up controllers...")
        
        mediaController = MediaController()
        
        print("✅ Controllers created")
        
        // Start monitoring
        mediaController?.startMonitoring()
        print("📻 Media controller started")
        
        // Initialize notch hover controller
        notchHoverController = NotchHoverController(mediaController: mediaController)
        print("🖱️ Notch hover controller started")
        
        // Initialize volume controller on MainActor
        Task { @MainActor in
            volumeController = VolumeController()
            volumeController?.startMonitoring()
            print("🔊 Volume controller started")
        }
    }
    
    private func requestPermissions() {
        // Note: MPMediaLibrary is not available on macOS
        // Media access is handled differently on macOS through the remote command center
        print("Setting up media controls for macOS")
        
        // No need for AVAudioSession on macOS - audio routing is handled differently
        print("Audio configuration completed")
    }
    
    @objc private func statusItemClicked() {
        NSApp.terminate(nil)
    }
    
    @objc private func testGeminiChat() {
        notchHoverController?.forceShowGeminiChat()
    }

    @objc private func testVolume() {
        print("Testing volume manually...")
        Task { @MainActor in
            volumeController?.showVolumeNotch()
        }
    }
    
    @objc private func forceMediaUpdate() {
        print("Forcing media update...")
        mediaController?.forceStatusUpdate()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        mediaController?.stopMonitoring()
        volumeController?.stopMonitoring()
        notchHoverController?.stopHoverDetection()
    }
} 