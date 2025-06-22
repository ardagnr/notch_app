import SwiftUI

struct ExpandedMediaView: View {
    @ObservedObject var mediaController: MediaController
    let onHover: (Bool) -> Void
    
    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    @State private var currentTime: Double = 0.0
    @State private var totalTime: Double = 180.0 // 3 dakika örnek
    @State private var isShuffled = false
    @State private var repeatMode = RepeatMode.off
    
    enum RepeatMode {
        case off, all, one
        
        var iconName: String {
            switch self {
            case .off: return "repeat"
            case .all: return "repeat"
            case .one: return "repeat.1"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Üst bölüm - Albüm kapağı ve şarkı bilgileri
            HStack(spacing: 16) {
                // Sol üst köşe - Albüm kapağı
                Group {
                    if let artwork = mediaController.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.system(size: 24, weight: .light))
                            )
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Sağ taraf - Şarkı bilgileri
                VStack(alignment: .leading, spacing: 4) {
                    // Şarkı adı - kalın beyaz harfler
                    Text(mediaController.currentTrack?.title ?? "Bilinmeyen Şarkı")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // Sanatçı ismi - daha küçük ve açık gri
                    Text(mediaController.currentTrack?.artist ?? "Bilinmeyen Sanatçı")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.gray.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Orta bölüm - Oynatma çubuğu (progress bar) ve zaman
            VStack(spacing: 8) {
                // Progress bar
                ProgressBarView(currentTime: $currentTime, totalTime: totalTime)
                
                // Zaman bilgileri
                HStack {
                    Text(formatTime(currentTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.7))
                    
                    Spacer()
                    
                    Text(formatTime(totalTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            
            // Alt bölüm - Oynatma kontrolleri
            HStack(spacing: 24) {
                // Shuffle
                MediaControlButton(
                    icon: "shuffle",
                    isActive: isShuffled,
                    size: .small
                ) {
                    isShuffled.toggle()
                }
                
                // Previous
                MediaControlButton(
                    icon: "backward.fill",
                    isActive: false,
                    size: .medium,
                    action: { 
                        mediaController.previousTrack()
                        // Force immediate update check
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            mediaController.forceStatusUpdate()
                        }
                    }
                )
                
                // Play/Pause (ana buton)
                MediaControlButton(
                    icon: mediaController.isPlaying ? "pause.fill" : "play.fill",
                    isActive: false,
                    size: .large,
                    isPrimary: true,
                    action: { mediaController.togglePlayPause() }
                )
                
                // Next
                MediaControlButton(
                    icon: "forward.fill",
                    isActive: false,
                    size: .medium,
                    action: { 
                        mediaController.nextTrack()
                        // Force immediate update check
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            mediaController.forceStatusUpdate()
                        }
                    }
                )
                
                // Repeat
                MediaControlButton(
                    icon: repeatMode.iconName,
                    isActive: repeatMode != .off,
                    size: .small
                ) {
                    switch repeatMode {
                    case .off: repeatMode = .all
                    case .all: repeatMode = .one
                    case .one: repeatMode = .off
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.95),
                            Color.black.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .frame(width: 360) // Daha geniş
        .scaleEffect(scale)
        .onHover { isHovered in
            onHover(isHovered)
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = isHovered ? 1.02 : 1.0
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4)) {
                scale = 1.0
            }
            startProgressSimulation()
        }
    }
    
    // Zaman formatı
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    // Progress simülasyonu (gerçek implementasyonda Spotify'dan gelecek)
    private func startProgressSimulation() {
        // Timer for progress simulation
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            // Only update if playing and within bounds
            if self.mediaController.isPlaying && self.currentTime < self.totalTime {
                self.currentTime += 1.0
            } else if self.currentTime >= self.totalTime {
                timer.invalidate() // Stop when song ends
            }
        }
    }
}

// Progress Bar Component
struct ProgressBarView: View {
    @Binding var currentTime: Double
    let totalTime: Double
    
    var progress: Double {
        totalTime > 0 ? currentTime / totalTime : 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background (koyu gri)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                // Progress (sarıdan yeşile gradient)
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
            .onTapGesture { location in
                // Progress bar'a tıklama ile konumu değiştirme
                let newProgress = location.x / geometry.size.width
                currentTime = totalTime * max(0, min(1, newProgress))
            }
        }
        .frame(height: 4)
    }
}

// Media Control Button Component
struct MediaControlButton: View {
    let icon: String
    let isActive: Bool
    let size: ButtonSize
    let isPrimary: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    enum ButtonSize {
        case small, medium, large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 44
            case .large: return 52
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 18
            case .large: return 22
            }
        }
    }
    
    init(icon: String, isActive: Bool = false, size: ButtonSize, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.isActive = isActive
        self.size = size
        self.isPrimary = isPrimary
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .bold))
                .foregroundColor(
                    isPrimary ? .white : 
                    (isActive ? .green : .white.opacity(0.9))
                )
                .frame(width: size.dimension, height: size.dimension)
                .background(
                    Circle()
                        .fill(
                            isPrimary ? 
                            Color.white.opacity(0.15) :
                            (isActive ? Color.green.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            isPrimary ? 
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1) :
                            nil
                        )
                )
                .scaleEffect(isPressed ? 0.9 : (isHovered ? 1.1 : 1.0))
                .animation(.easeInOut(duration: 0.2), value: isPressed)
                .animation(.easeInOut(duration: 0.3), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// Basınç efektleri için yardımcı extension
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

#Preview {
    ExpandedMediaView(
        mediaController: MediaController(),
        onHover: { _ in }
    )
    .padding()
    .background(Color.gray)
} 