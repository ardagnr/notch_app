import Foundation
import SwiftUI
import UserNotifications

class TimerController: ObservableObject {
    @Published var isRunning = false
    @Published var timeRemaining: TimeInterval = 0
    @Published var initialTime: TimeInterval = 0
    @Published var selectedMinutes: Int = 5
    @Published var selectedSeconds: Int = 0
    
    private var timer: Timer?
    private var endTime: Date?
    
    // Önceden ayarlanmış süre seçenekleri
    let presetTimes = [
        (name: "5 dakika", minutes: 5, seconds: 0),
        (name: "10 dakika", minutes: 10, seconds: 0),
        (name: "15 dakika", minutes: 15, seconds: 0),
        (name: "25 dakika", minutes: 25, seconds: 0), // Pomodoro
        (name: "30 dakika", minutes: 30, seconds: 0),
        (name: "45 dakika", minutes: 45, seconds: 0),
        (name: "1 saat", minutes: 60, seconds: 0)
    ]
    
    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progressPercentage: Double {
        guard initialTime > 0 else { return 0 }
        return (initialTime - timeRemaining) / initialTime
    }
    
    func startTimer(minutes: Int, seconds: Int) {
        let totalSeconds = TimeInterval(minutes * 60 + seconds)
        startTimer(duration: totalSeconds)
    }
    
    func startTimer(duration: TimeInterval) {
        guard duration > 0 else { return }
        
        stopTimer()
        
        initialTime = duration
        timeRemaining = duration
        endTime = Date().addingTimeInterval(duration)
        isRunning = true
        
        // Optimized timer - 0.5s interval is sufficient for UI updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("⏱️ Timer started: \(formattedTimeRemaining)")
    }
    
    func pauseTimer() {
        guard isRunning else { return }
        
        timer?.invalidate()
        timer = nil
        isRunning = false
        endTime = nil
        
        print("⏸️ Timer paused at: \(formattedTimeRemaining)")
    }
    
    func resumeTimer() {
        guard !isRunning && timeRemaining > 0 else { return }
        
        endTime = Date().addingTimeInterval(timeRemaining)
        isRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("▶️ Timer resumed: \(formattedTimeRemaining)")
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        timeRemaining = 0
        initialTime = 0
        endTime = nil
        
        print("⏹️ Timer stopped")
    }
    
    func resetTimer() {
        let wasRunning = isRunning
        stopTimer()
        
        if initialTime > 0 {
            timeRemaining = initialTime
            if wasRunning {
                resumeTimer()
            }
        }
        
        print("🔄 Timer reset to: \(formattedTimeRemaining)")
    }
    
    private func updateTimer() {
        guard let endTime = endTime else {
            stopTimer()
            return
        }
        
        let now = Date()
        if now >= endTime {
            // Timer bitti
            timeRemaining = 0
            isRunning = false
            timer?.invalidate()
            timer = nil
            self.endTime = nil
            
            timerFinished()
        } else {
            timeRemaining = endTime.timeIntervalSince(now)
        }
    }
    
    private func timerFinished() {
        print("🔔 Timer finished!")
        
        // Sistem bildirimi gönder
        sendNotification()
        
        // Haptic feedback (macOS'ta NSHapticFeedbackManager kullanabilir)
        NSSound.beep()
    }
    
    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Sayaç Bitti!"
        content.body = "Belirlediğiniz süre tamamlandı."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "timer-finished",
            content: content,
            trigger: nil // Hemen gönder
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error)")
            } else {
                print("✅ Timer notification sent")
            }
        }
    }
    
    func setPresetTime(minutes: Int, seconds: Int) {
        selectedMinutes = minutes
        selectedSeconds = seconds
    }
    
    deinit {
        timer?.invalidate()
    }
} 