import SwiftUI

struct NotchMaskView: View {
    let track: MediaTrack?
    let isPlaying: Bool
    let artwork: NSImage?
    let onHover: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Sol taraf - Albüm kapağı (yanlara daha yakın)
            HStack {
                Group {
                    if let artwork = artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(1.0, contentMode: .fill) // Tam kare oranı
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.system(size: 10)) // Bir önceki ikon boyutu
                            )
                    }
                }
                .frame(width: 24, height: 24) // Daha küçük albüm kapağı
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .offset(x: -3, y: -18) // İkonları daha yukarı taşı
            }
            .frame(width: 55) // Yanlara 5px daha genişletildi (50'den 55'e)
            
            // Orta boşluk - Spacer kullanarak basitleştir
            Spacer()
                .frame(width: 130)
            
            // Sağ taraf - Müzik durumu (yanlara daha yakın)
            HStack {
                if isPlaying {
                    // Option 1: Modern Waveform Indicator (daha büyük ve modern)
                    ModernWaveformIndicator()
                        .frame(width: 32, height: 16) // Daha büyük gösterge
                        .offset(x: 3, y: -18) // İkonları daha yukarı taşı
                } else {
                    // Modern pause button
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(.white.opacity(0.9))
                        .font(.system(size: 16)) // Daha büyük ikon
                        .frame(width: 32, height: 16)
                        .offset(x: 8, y: -18) // İkonları daha yukarı taşı
                }
            }
            .frame(width: 70) // Yanlara 5px daha genişletildi (65'ten 70'e)
        }
        .frame(height: 0.5) // Ultra minimal yükseklik - custom DynamicNotchKit ile
        .background(Color.black.opacity(1.0)) // Tam opak siyah, bulanıklık yok
        // Hover area için minimal padding ekle
        .padding(.vertical, 0.5) // Ultra minimal hover area
        .padding(.horizontal, 0.5) // Ultra minimal hover area
        .background(Color.clear)
        .contentShape(Rectangle()) // Tüm alanın hover'a duyarlı olmasını sağla
        .onHover { isHovered in
            print("🎵 NotchMaskView hover: \(isHovered)") // Debug için
            onHover(isHovered)
        }
    }
}

struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        // M4 MacBook fiziksel çentiği gibi daha yumuşak köşeler
        let cornerRadius: CGFloat = min(width * 0.15, height * 0.8) // Orantılı yumuşak köşeler
        
        // M4 çentik benzeri yumuşak şekil
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0))
        
        // Sağ alt köşe - çok sert geçiş
        path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
        path.addCurve(
            to: CGPoint(x: width - cornerRadius, y: height),
            control1: CGPoint(x: width, y: height - cornerRadius * 0.05),
            control2: CGPoint(x: width - cornerRadius * 0.05, y: height)
        )
        
        // Alt çizgi
        path.addLine(to: CGPoint(x: cornerRadius, y: height))
        
        // Sol alt köşe - çok sert geçiş
        path.addCurve(
            to: CGPoint(x: 0, y: height - cornerRadius),
            control1: CGPoint(x: cornerRadius * 0.05, y: height),
            control2: CGPoint(x: 0, y: height - cornerRadius * 0.05)
        )
        
        path.closeSubpath()
        
        return path
    }
}

struct ModernWaveformIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) { // Daha geniş spacing
            ForEach(0..<5) { index in // 5 çubuk daha modern görünüm
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.gray.opacity(0.8), .white.opacity(0.6)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: isAnimating ? CGFloat.random(in: 4...14) : 4) // Daha büyük çubuklar
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ModernCircularIndicator: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.7)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [.gray.opacity(0.7), .white.opacity(0.5)]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .rotationEffect(.degrees(rotationAngle))
            .onAppear {
                withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
    }
}

struct ModernPulseIndicator: View {
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.gray.opacity(0.6), .white.opacity(0.4)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: isPulsing ? CGFloat.random(in: 6...12) : 6)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: isPulsing
                    )
            }
        }
        .onAppear {
            isPulsing = true
        }
    }
}

#Preview {
    NotchMaskView(
        track: MediaTrack(
            title: "Sample Song",
            artist: "Sample Artist", 
            album: "Sample Album"
        ),
        isPlaying: true,
        artwork: nil,
        onHover: { _ in }
    )
    .padding()
    .background(Color.gray)
} 