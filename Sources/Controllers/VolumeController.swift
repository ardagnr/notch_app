import Foundation
import AVFoundation
import CoreAudio
import IOKit
import DynamicNotchKit
import SwiftUI

@MainActor
class VolumeController: ObservableObject, Sendable {
    @Published var currentVolume: Float = 0
    @Published var isMuted: Bool = false
    
    private var volumeNotch: DynamicNotch<VolumeNotchView, EmptyView, EmptyView>?
    private var hideVolumeTimer: Timer?
    
    private let notificationCenter = DistributedNotificationCenter.default()
    
    func startMonitoring() {
        print("Starting volume monitoring...")
        
        // Monitor volume changes - comprehensive notification coverage
        let volumeNotifications = [
            "com.apple.sound.settingsChangedNotification",
            "com.apple.BezelServices.VolumeChanged", 
            "com.apple.sound.volumeChanged",
            "com.apple.BezelServices",
            "com.apple.audio.VolumeChanged",
            "com.apple.audio.systemHasPowerChanged",
            "com.apple.audio.OutputDeviceChanged",
            "VolumeChanged",
            "AudioVolumeChanged"
        ]
        
        for notificationName in volumeNotifications {
            notificationCenter.addObserver(
                self,
                selector: #selector(volumeDidChange),
                name: NSNotification.Name(notificationName),
                object: nil
            )
            print("Registered for volume notification: \(notificationName)")
        }
        
        // Also use regular NotificationCenter for system notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(volumeDidChange),
            name: NSNotification.Name("NSSystemVolumeDidChangeNotification"),
            object: nil
        )
        
        // Optimized polling mechanism - reduced frequency for better performance
        Timer.scheduledTimer(withTimeInterval: 0.33, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                self.pollVolumeChanges()
            }
        }
        
        // Initial volume
        updateCurrentVolume()
        
        print("Volume monitoring setup complete")
        print("🔊 Initial volume: \(Int(currentVolume * 100))%")
    }
    
    private var lastVolume: Float = -1
    
    @MainActor
    private func pollVolumeChanges() {
        let currentVol = getCurrentSystemVolume()
        
        // Use smaller threshold for more sensitive detection
        let volumeThreshold: Float = 0.001 // Very sensitive to changes
        
        if abs(lastVolume - currentVol) > volumeThreshold && lastVolume != -1 {
            print("🔊 Volume change: \(Int(lastVolume * 100))% -> \(Int(currentVol * 100))%")
            self.currentVolume = currentVol
            self.showVolumeNotch()
        }
        
        lastVolume = currentVol
    }
    
    func stopMonitoring() {
        notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        hideVolumeTimer?.invalidate()
        
        Task {
            await volumeNotch?.hide()
        }
    }
    
    @objc private func volumeDidChange() {
        print("🔊 Volume notification received!")
        updateCurrentVolume()
        Task { @MainActor in
            self.showVolumeNotch()
        }
    }
    
    private func updateCurrentVolume() {
        let volume = getCurrentSystemVolume()
        let muted = getCurrentSystemMuted()
        
        DispatchQueue.main.async {
            self.currentVolume = volume
            self.isMuted = muted
        }
    }
    
    private func getCurrentSystemVolume() -> Float {
        var volume: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        
        // Get default audio output device
        var deviceID: AudioDeviceID = 0
        var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &deviceSize, &deviceID) == noErr {
            // Get volume
            var volumeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &size, &volume)
        }
        
        return volume
    }
    
    private func getCurrentSystemMuted() -> Bool {
        var muted: UInt32 = 0
        var mutedSize = UInt32(MemoryLayout<UInt32>.size)
        
        // Get default audio output device
        var deviceID: AudioDeviceID = 0
        var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &deviceSize, &deviceID) == noErr {
            // Get mute status
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &mutedSize, &muted)
        }
        
        return muted != 0
    }
    

    
    @MainActor
    func showVolumeNotch() {
        hideVolumeTimer?.invalidate()
        
        // Only create notch if it doesn't exist, otherwise just update timer
        if volumeNotch == nil {
            volumeNotch = DynamicNotch {
                VolumeNotchView(
                    volumeController: self,
                    type: .volume
                )
            }
            
            Task {
                print("🔊 Volume notch opened: \(Int((currentVolume) * 100))%")
                await volumeNotch?.expand()
            }
        } else {
            print("🔊 Volume updated: \(Int((currentVolume) * 100))%")
        }
        
        // Reset auto-hide timer - 1 second after last change
        hideVolumeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                print("🔊 Volume notch hiding...")
                await self?.volumeNotch?.hide()
                self?.volumeNotch = nil
            }
        }
    }
    

}

enum VolumeType {
    case volume
    
    var icon: String {
        switch self {
        case .volume:
            return "speaker.wave.3.fill"
        }
    }
    
    var mutedIcon: String {
        switch self {
        case .volume:
            return "speaker.slash.fill"
        }
    }
} 