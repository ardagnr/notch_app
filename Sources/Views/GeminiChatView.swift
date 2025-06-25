import SwiftUI

struct GeminiChatView: View {
    @ObservedObject var geminiController: GeminiController
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    var onMenuSelection: ((NotchMenuOption) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Top menu bar
            HStack(spacing: 12) {
                // Current notch indicator
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Gemini AI")
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
                    // Timer button
                    Button(action: { onMenuSelection?(.timer) }) {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Sayaç")
                    
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
                    
                    // Clear chat button
                    Button(action: { geminiController.clearChat() }) {
                        Image(systemName: "trash")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Sohbeti Temizle")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    // LazyVStack - sadece görünen mesajları render eder (GPU tasarrufu)
                    LazyVStack(spacing: 12) {
                        if geminiController.messages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("Gemini AI ile sohbete başla!")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("Herhangi bir şey sorabilirsin...")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.top, 20)
                        } else {
                            ForEach(geminiController.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if geminiController.isLoading {
                            HStack {
                                LoadingDots()
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: geminiController.messages.count) { _ in
                    if let lastMessage = geminiController.messages.last {
                        // Daha hafif animasyon - GPU tasarrufu
                        withAnimation(.linear(duration: 0.2)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            HStack(spacing: 8) {
                TextField("Mesajını yaz...", text: $messageText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: messageText.isEmpty ? "mic" : "paperplane.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(messageText.isEmpty ? Color.white.opacity(0.2) : Color.blue)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(geminiController.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.15))
        }
        .frame(width: 380, height: 380)
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedMessage.isEmpty else { 
            return 
        }
        
        Task {
            await geminiController.sendMessage(trimmedMessage)
        }
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.blue.opacity(0.8))
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Gemini")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.15))
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct LoadingDots: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.15))
        )
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    GeminiChatView(geminiController: GeminiController())
        .background(Color.black)
} 