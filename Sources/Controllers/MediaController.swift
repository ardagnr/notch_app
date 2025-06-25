import Foundation
import MediaPlayer
import DynamicNotchKit
import SwiftUI
import ScriptingBridge

// MARK: - Custom Animation Style Extension
extension DynamicNotchStyle {
    /// Soft notch style with smoother animations
    static let softNotch: DynamicNotchStyle = .notch(topCornerRadius: 15, bottomCornerRadius: 20)
    
    /// Custom ultra-soft animations with faster opening
    var softOpeningAnimation: Animation {
        .easeInOut(duration: 0.6) // Hızlandırılmış açılış (was 0.8)
    }
    
    var softClosingAnimation: Animation {
        .easeInOut(duration: 0.9) // Daha da yavaş ve yumuşak kapanış
    }
    
    var softConversionAnimation: Animation {
        .easeInOut(duration: 0.7) // Çok yumuşak geçiş
    }
}

class MediaController: ObservableObject {
    @Published var currentTrack: MediaTrack?
    @Published var isPlaying: Bool = false
    @Published var artwork: NSImage?

    
    private var compactNotch: DynamicNotch<NotchMaskView, EmptyView, EmptyView>?
    private var expandedNotch: DynamicNotch<AnyView, EmptyView, EmptyView>?
    private var remoteCommandCenter: MPRemoteCommandCenter
    private var nowPlayingInfoCenter: MPNowPlayingInfoCenter
    private var isCurrentlyExpanded: Bool = false
    private var isTransitioning: Bool = false
    
    // Ultra-efficient monitoring
    private var mediaRemoteObserver: Any?
    private var applicationObserver: NSObjectProtocol?
    private var workspaceObserver: NSObjectProtocol?
    private var lastTrackInfo: String?
    private var spotifyIsRunning: Bool = false
    
    // Performance optimizations
    private var cachedAppleScript: NSAppleScript?
    private var lastUpdateTime: Date = Date()
    
    init() {
        self.remoteCommandCenter = MPRemoteCommandCenter.shared()
        self.nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    }
    
    func startMonitoring() {
        print("🚀 Starting ultra-efficient media monitoring...")
        
        // Setup remote command center
        setupRemoteCommands()
        
        // Listen to macOS media events (no polling needed!)
        setupMediaRemoteObserver()
        
        // Monitor Spotify app lifecycle
        setupAppLifecycleMonitoring()
        
        // Initial check only once
        checkSpotifyStatusOnce()
        
        // Additional startup check after a delay to catch any missed state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkSpotifyStatusOnce()
        }
    }
    
    func stopMonitoring() {
        print("🛑 Stopping ultra-efficient monitoring...")
        
        // Remove all observers
        NotificationCenter.default.removeObserver(self)
        if let observer = applicationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        
        // Clean up all references
        mediaRemoteObserver = nil
        applicationObserver = nil
        workspaceObserver = nil
        cachedAppleScript = nil
        
        Task {
            await compactNotch?.hide()
            await expandedNotch?.hide()
            compactNotch = nil
            expandedNotch = nil
        }
    }
    
    private func setupRemoteCommands() {
        // Play command
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.playCommand.addTarget { [weak self] _ in
            self?.playMedia()
            return .success
        }
        
        // Pause command
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pauseMedia()
            return .success
        }
        
        // Toggle play/pause command
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
        remoteCommandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        // Next track command
        remoteCommandCenter.nextTrackCommand.isEnabled = true
        remoteCommandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        // Previous track command
        remoteCommandCenter.previousTrackCommand.isEnabled = true
        remoteCommandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
    }
    

    
    // MARK: - Ultra-Efficient Zero-Polling Methods
    
    private func setupMediaRemoteObserver() {
        // Comprehensive notification observers - tamamen pasif, enerji dostu
        let notificationNames = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "MPNowPlayingInfoDidChangeNotification", 
            "com.spotify.client.PlaybackStateChanged",
            "kMRNowPlayingPlaybackQueueChangedNotification",
            "kMRPlaybackQueueContentItemsChangedNotification"
        ]
        
        for name in notificationNames {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(mediaInfoChanged),
                name: NSNotification.Name(name),
                object: nil
            )
        }
        
        // System power notifications - enerji durumuna göre optimize
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        print("🔔 Passive notification observers started - zero polling!")
        
        // Backup monitoring sadece gerektiğinde
        startBackupMonitoring()
    }
    
    @objc private func systemWillSleep() {
        print("💤 System going to sleep - pausing monitoring")
        // Sleep modunda hiçbir şey yapma
    }
    
    @objc private func systemDidWake() {
        print("🌅 System woke up - resuming monitoring")
        // Tek seferlik status check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkSpotifyStatusOnce()
        }
    }
    
    private func setupAppLifecycleMonitoring() {
        // Monitor Spotify launch/quit - only when app state changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier == "com.spotify.client" {
                print("🚀 Spotify launched - checking status")
                self?.spotifyIsRunning = true
                self?.checkSpotifyStatusOnce()
            }
        }
        
        // Monitor app termination
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier == "com.spotify.client" {
                print("🛑 Spotify quit - hiding notch")
                self?.spotifyIsRunning = false
                Task { @MainActor in
                    self?.currentTrack = nil
                    self?.artwork = nil
                    self?.isPlaying = false
                    self?.hideNotch()
                }
            }
        }
    }
    
    @objc private func mediaInfoChanged() {
        // Only check if Spotify is actually running
        guard spotifyIsRunning else { return }
        print("📻 Media info changed - updating")
        checkSpotifyStatusOnce()
    }
    
    private func startBackupMonitoring() {
        // Optimized backup monitoring - reduced to essential checks only
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, self.spotifyIsRunning else { return }
            
            // Only backup check if no current track or discrepancy detected
            if self.currentTrack == nil || !self.isPlaying {
                self.checkSpotifyStatusSilently()
            }
        }
    }
    
    private func checkSpotifyStatusSilently() {
        // Backup check - always process to catch missed events
        let script = """
        tell application "Spotify"
            if player state is playing then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set artworkUrl to artwork url of current track
                set playState to "playing"
                return trackName & "|||" & artistName & "|||" & albumName & "|||" & playState & "|||" & artworkUrl
            else if player state is paused then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set artworkUrl to artwork url of current track
                set playState to "paused"
                return trackName & "|||" & artistName & "|||" & albumName & "|||" & playState & "|||" & artworkUrl
            else
                return "stopped"
            end if
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            
            if error != nil {
                // Silent error handling for backup monitoring
                return
            }
            
            if let resultString = result.stringValue {
                // Always process - don't rely only on track changes
                if resultString != lastTrackInfo || (resultString.contains("playing") && currentTrack == nil) {
                    print("🔄 Backup monitoring: \(resultString)")
                    lastTrackInfo = resultString
                    parseSpotifyResult(resultString)
                }
            }
        }
    }
    
    private func checkSpotifyStatusOnce() {
        // Single, targeted check - no repeated polling!
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        spotifyIsRunning = runningApps.contains { $0.bundleIdentifier == "com.spotify.client" && !$0.isTerminated }
        
        guard spotifyIsRunning else {
            if currentTrack != nil {
                print("🛑 Spotify not running - clearing")
                Task { @MainActor in
                    self.currentTrack = nil
                    self.artwork = nil
                    self.isPlaying = false
                    self.hideNotch()
                }
            }
            return
        }
        
        // Only make AppleScript call when needed
        checkSpotifyStatus()
    }
    

    
    private func checkSpotifyStatus() {
        // Light throttle - allow more frequent updates
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) > 0.3 else { return }
        lastUpdateTime = now
        
        // Use cached AppleScript for performance
        if cachedAppleScript == nil {
            let script = """
            tell application "Spotify"
                if player state is playing then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set artworkUrl to artwork url of current track
                    set playState to "playing"
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & playState & "|||" & artworkUrl
                else if player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set artworkUrl to artwork url of current track
                    set playState to "paused"
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & playState & "|||" & artworkUrl
                else
                    return "stopped"
                end if
            end tell
            """
            cachedAppleScript = NSAppleScript(source: script)
        }
        
        guard let appleScript = cachedAppleScript else { return }
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ AppleScript error: \(error)")
            return
        }
        
        if let resultString = result.stringValue {
            // Only process if info has changed
            if resultString != lastTrackInfo {
                print("🔄 Track changed: \(resultString)")
                lastTrackInfo = resultString
                parseSpotifyResult(resultString)
            }
        }
    }
    
    private func parseSpotifyResult(_ result: String) {
        guard result != "stopped" else {
            Task { @MainActor in
                print("🎵 Spotify stopped - hiding notch")
                self.currentTrack = nil
                self.artwork = nil
                self.isPlaying = false
                self.hideNotch()
            }
            return
        }
        
        let components = result.components(separatedBy: "|||")
        guard components.count >= 4 else { return }
        
        let trackName = components[0]
        let artistName = components[1]
        let albumName = components[2]
        let playState = components[3]
        let artworkUrl = components.count > 4 ? components[4] : nil
        
        Task { @MainActor in
            let newTrack = MediaTrack(title: trackName, artist: artistName, album: albumName)
            
            // Check if track actually changed
            let trackChanged = self.currentTrack?.title != trackName || 
                             self.currentTrack?.artist != artistName
            
            self.currentTrack = newTrack
            self.isPlaying = (playState == "playing")
            
            // Download artwork only if track changed and URL is available
            if trackChanged, let artworkUrl = artworkUrl, !artworkUrl.isEmpty {
                self.downloadArtwork(from: artworkUrl)
            }
            
            // Show/hide notch based on playing state
            if self.isPlaying {
                if trackChanged {
                    print("🎵 New track: \(trackName) by \(artistName)")
                }
                // Always try to show notch when playing
                print("🎵 Music is playing - ensuring notch visibility")
                if !self.isCurrentlyExpanded && self.compactNotch == nil {
                    print("🎵 No notch visible - creating compact notch")
                    self.showCompactNotch()
                } else if !self.isCurrentlyExpanded {
                    print("🎵 Compact notch already exists")
                } else {
                    print("🎵 Expanded notch is open")
                }
            } else if playState == "paused" {
                // Paused state - keep notch but update UI
                print("⏸️ Music paused - keeping notch visible but updating state")
                // Notch'u gizleme, sadece state'i güncelle
                // NotchMaskView ve ExpandedMediaView otomatik olarak isPlaying değişikliğini görecek
            } else {
                // Stopped state - hide notch completely  
                print("🛑 Music stopped - hiding notches")
                self.hideNotch()
            }
        }
    }
    
    @MainActor
    private func showCompactNotch() {
        // Safety checks
        guard !isCurrentlyExpanded, !isTransitioning, compactNotch == nil else {
            print("⚠️ Cannot show compact - state: expanded=\(isCurrentlyExpanded), transitioning=\(isTransitioning), exists=\(compactNotch != nil)")
            return
        }
        
        print("🎵 Showing compact notch")
            compactNotch = DynamicNotch {
                NotchMaskView(
                    mediaController: self,
                    onHover: { [weak self] isHovered in
                        if isHovered {
                        print("🎵 Mouse entered NotchMask - switching to expanded")
                        self?.switchToExpanded()
                        }
                    }
                )
        }
        
        Task {
            await compactNotch?.expand()
        }
    }
    
    @MainActor
    private func switchToExpanded() {
        // Prevent multiple transitions
        guard !isTransitioning else {
            print("⚠️ Already transitioning to expanded - skipping")
            return
        }
        
        print("🎵 Switching to expanded")
        isTransitioning = true
        isCurrentlyExpanded = true
        
        Task {
            // Soft cross-fade transition
            await showExpandedNotchInternal()
            
            // Small overlap for smooth transition
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
            
            await compactNotch?.hide()
            compactNotch = nil
            
            isTransitioning = false
            print("✅ Soft transition to expanded complete")
        }
    }
    
    @MainActor
    private func switchToCompact() {
        // Prevent multiple transitions
        guard !isTransitioning else {
            print("⚠️ Already transitioning to compact - skipping")
            return
        }
        
        print("🎵 Switching to compact")
        isTransitioning = true
        isCurrentlyExpanded = false
        
        Task {
            // Wait for expanded to start closing first
            await expandedNotch?.hide()
            
            // Even shorter wait for ultra-fast compact appearance
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds (was 0.2)
            
            // Then show compact (faster transition)
            await showCompactNotchInternal()
            expandedNotch = nil
            
            isTransitioning = false
            print("✅ Fast transition to compact complete")
        }
    }
    
    @MainActor
    private func showExpandedNotchInternal() async {
        guard expandedNotch == nil else { return }
        
        print("🎵 Creating expanded notch")
            expandedNotch = DynamicNotch(
                hoverBehavior: [.keepVisible],
                style: .softNotch,
                expanded: { [weak self] in
                    guard let self = self else { return AnyView(EmptyView()) }
                    return AnyView(
                        ExpandedMediaView(
                            mediaController: self,
                            onHover: { [weak self] isHovered in
                                if !isHovered {
                                    print("🎵 Mouse left ExpandedMedia")
                                                                    // Faster transition için delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        // Double check: hala expanded durumda mı ve transition olmuyorsa
                                        guard let self = self,
                                              self.isCurrentlyExpanded,
                                              !self.isTransitioning else {
                                            print("🔄 State changed during delay - skipping transition")
                                            return
                                        }
                                        print("🔄 Confirmed mouse exit - switching to compact")
                                        self.switchToCompact()
                                    }
                                } else {
                                    print("🎵 Mouse re-entered ExpandedMedia")
                                }
                            }
                        )
                    )
                }
            )
        
            await expandedNotch?.expand()
        }
    
    @MainActor
    private func showCompactNotchInternal() async {
        guard compactNotch == nil else { return }
        
        print("🎵 Creating compact notch")
        compactNotch = DynamicNotch(
            hoverBehavior: [.keepVisible],
            style: .softNotch
        ) {
            NotchMaskView(
                mediaController: self,
                onHover: { [weak self] isHovered in
                    if isHovered {
                        print("🎵 Mouse entered NotchMask")
                        // Check if we can transition
                        guard let self = self, !self.isTransitioning else {
                            print("⚠️ Cannot switch - already transitioning")
                            return
                        }
                        print("🔄 Switching to expanded")
                        self.switchToExpanded()
                    }
                }
            )
        }
        
        await compactNotch?.expand()
    }
    
    @MainActor
    private func showExpandedNotch() {
        // Bu fonksiyonu kullanmıyoruz artık, switchToExpanded kullanıyoruz
        switchToExpanded()
    }
    
    private func hideNotch() {
        print("🎵 Hiding all notches...")
        isTransitioning = true
        
        Task {
            await compactNotch?.hide()
            await expandedNotch?.hide()
            compactNotch = nil
            expandedNotch = nil
            
            await MainActor.run {
                isCurrentlyExpanded = false
                isTransitioning = false
            }
        }
    }
    
    // MARK: - Media Control Actions
    private func playMedia() {
        print("Play media requested")
        executeSpotifyCommand("play")
    }
    
    private func pauseMedia() {
        print("Pause media requested")
        executeSpotifyCommand("pause")
    }
    
    func togglePlayPause() {
        print("Toggle play/pause requested")
        executeSpotifyCommand("playpause")
    }
    
    func nextTrack() {
        print("Next track requested")
        executeSpotifyCommand("next track")
    }
    
    func previousTrack() {
        print("Previous track requested")
        executeSpotifyCommand("previous track")
    }
    
    func forceStatusUpdate() {
        print("🔄 Force status update requested")
        // Reset throttling to allow immediate check
        lastUpdateTime = Date(timeIntervalSince1970: 0)
        checkSpotifyStatusOnce()
        
        // Also force backup check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkSpotifyStatusSilently()
        }
    }
    
    private func executeSpotifyCommand(_ command: String) {
        let script = """
        tell application "Spotify"
            \(command)
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            
            if let error = error {
                print("Spotify command error: \(error)")
            } else {
                print("Spotify command executed: \(command)")
                // Immediate update after command
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.checkSpotifyStatusOnce()
                }
                // Secondary check to catch delayed changes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.checkSpotifyStatusSilently()
                }
            }
        }
    }
    
    private func downloadArtwork(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("Failed to download artwork: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self?.artwork = image
                    print("🎨 Artwork downloaded successfully")
                }
            }
        }.resume()
    }
}

// MARK: - MediaTrack Model
struct MediaTrack {
    let title: String
    let artist: String
    let album: String
} 