import SwiftUI

struct TimerNotchView: View {
    @ObservedObject var timerController: TimerController
    @State private var showingPresets = true
    var onMenuSelection: ((NotchMenuOption) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Top menu bar
            HStack(spacing: 12) {
                // Current notch indicator
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Sayaç")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
                
                Spacer()
                
                // Menu buttons
                HStack(spacing: 8) {
                    // Gemini button
                    Button(action: { onMenuSelection?(.gemini) }) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Gemini AI")
                    
                    // Notes button
                    Button(action: { onMenuSelection?(.notes) }) {
                        Image(systemName: "note.text")
                            .foregroundColor(.yellow)
                            .font(.caption)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Notlar")
                    
                    // Stop timer button (when active)
                    if timerController.isRunning || timerController.timeRemaining > 0 {
                        Button(action: {
                            timerController.stopTimer()
                            showingPresets = true
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Sayacı Durdur")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))
            
            if showingPresets && !timerController.isRunning && timerController.timeRemaining == 0 {
                // Preset selection view
                presetSelectionView
            } else {
                // Active timer view
                activeTimerView
            }
        }
        .frame(width: 380, height: 380)
    }
    
    private var presetSelectionView: some View {
        VStack(spacing: 12) {
            Text("Süre Seçin")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 8)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(timerController.presetTimes, id: \.name) { preset in
                    Button(action: {
                        timerController.setPresetTime(minutes: preset.minutes, seconds: preset.seconds)
                        timerController.startTimer(minutes: preset.minutes, seconds: preset.seconds)
                        showingPresets = false
                    }) {
                        VStack(spacing: 4) {
                            Text(preset.name)
                                .font(.body.weight(.medium))
                                .foregroundColor(.white)
                            
                            Text("\(preset.minutes):\(String(format: "%02d", preset.seconds))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            
            // Custom time picker
            HStack {
                Text("Özel:")
                    .foregroundColor(.white.opacity(0.7))
                
                Picker("Dakika", selection: $timerController.selectedMinutes) {
                    ForEach(0..<60) { minute in
                        Text("\(minute)m").tag(minute)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .foregroundColor(.white)
                
                Picker("Saniye", selection: $timerController.selectedSeconds) {
                    ForEach(0..<60) { second in
                        Text("\(second)s").tag(second)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .foregroundColor(.white)
                
                Button("Başlat") {
                    timerController.startTimer(
                        minutes: timerController.selectedMinutes, 
                        seconds: timerController.selectedSeconds
                    )
                    showingPresets = false
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var activeTimerView: some View {
        VStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: timerController.progressPercentage)
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: timerController.progressPercentage)
                
                VStack(spacing: 2) {
                    Text(timerController.formattedTimeRemaining)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    
                    Text(timerController.isRunning ? "Çalışıyor" : "Duraklatıldı")
                        .font(.caption)
                        .foregroundColor(timerController.isRunning ? .orange : .white.opacity(0.6))
                }
            }
            .padding(.top, 8)
            
            // Controls
            HStack(spacing: 16) {
                Button(action: {
                    if timerController.isRunning {
                        timerController.pauseTimer()
                    } else {
                        timerController.resumeTimer()
                    }
                }) {
                    Image(systemName: timerController.isRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.orange.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: timerController.resetTimer) {
                    Image(systemName: "gobackward")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 16)
        }
    }
}

#Preview {
    TimerNotchView(timerController: TimerController())
} 