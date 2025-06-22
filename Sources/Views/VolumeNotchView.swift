import SwiftUI

struct VolumeNotchView: View {
    @ObservedObject var volumeController: VolumeController
    let type: VolumeType
    
    @State private var animatedVolume: Float = 0
    
    private var volume: Float {
        switch type {
        case .volume:
            return volumeController.currentVolume
        }
    }
    
    private var isMuted: Bool {
        switch type {
        case .volume:
            return volumeController.isMuted
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon - Minimalist design
            Image(systemName: isMuted ? type.mutedIcon : type.icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(isMuted ? .white.opacity(0.4) : .white.opacity(0.8))
                .frame(width: 20, height: 20)
            
            // Volume bar - Clean and simple
            VolumeBar(volume: animatedVolume, isMuted: isMuted, type: type)
                .frame(width: 100, height: 4)
            
            // Volume percentage - Subtle
            Text("\(Int(animatedVolume * 100))%")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white)
                .frame(minWidth: 28, alignment: .trailing)
                .opacity(isMuted ? 0.4 : 0.8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .onAppear {
            // Immediate show without animation for instant feel
            animatedVolume = volume
        }
        .onChange(of: volume) { newValue in
            // Very fast animation for instant response
            withAnimation(.easeOut(duration: 0.08)) {
                animatedVolume = newValue
            }
        }
    }
}

struct VolumeBar: View {
    let volume: Float
    let isMuted: Bool
    let type: VolumeType
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background - Simple dark
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))
                
                // Volume fill - Clean white gradient
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(volume))
                    .opacity(isMuted ? 0.3 : 1.0)
                    .animation(.easeOut(duration: 0.05), value: volume)
            }
        }
    }
}

#Preview {
    let volumeController = VolumeController()
    
    VStack(spacing: 20) {
        VolumeNotchView(volumeController: volumeController, type: .volume)
    }
    .padding()
    .background(Color.black)
} 