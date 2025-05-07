import Foundation
// Import the VoiceAssistantManager
import Speech
import SwiftUI

// Forward declare the types we need
@_silgen_name("dummy")
private func dummy() {}

struct VoiceAssistantView: View {
    @ObservedObject var viewModel: KitchenViewModel
    @StateObject private var voiceAssistant = VoiceAssistantManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showingConfirmation = false
    @State private var itemName = ""
    @State private var quantity = 1
    @State private var unit = "each"
    @State private var showFeedback = false
    @State private var feedbackMessage = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Voice Assistant")
                    .font(.title2)
                    .fontWeight(.bold)

                // Status indicator
                if voiceAssistant.isListening {
                    Text("Listening...")
                        .font(.headline)
                        .foregroundColor(.blue)
                } else if voiceAssistant.processingCommand {
                    Text("Processing...")
                        .font(.headline)
                        .foregroundColor(.orange)
                } else if let error = voiceAssistant.errorMessage {
                    Text(error)
                        .font(.headline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if showFeedback {
                    Text(feedbackMessage)
                        .font(.headline)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Recognized text display
                if !voiceAssistant.recognizedText.isEmpty {
                    Text(voiceAssistant.recognizedText)
                        .font(.body)
                        .padding()
                        .background(Color("CardColor").opacity(0.8))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }

                // Microphone button
                Button(action: {
                    if voiceAssistant.isListening {
                        voiceAssistant.stopListening()
                    } else {
                        showFeedback = false
                        voiceAssistant.startListening()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(voiceAssistant.isListening ? Color.red : Color("ActionColor"))
                            .frame(width: 80, height: 80)

                        if voiceAssistant.processingCommand {
                            ProgressView()
                                .scaleEffect(1.5)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: voiceAssistant.isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .disabled(voiceAssistant.processingCommand)

                Text("Try saying: \"Add 2 pounds of ground beef\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Close") {
                    if voiceAssistant.isListening {
                        voiceAssistant.stopListening()
                    }
                    dismiss()
                }
            }
            .padding()
            .background(Color("BackgroundColor"))
            .cornerRadius(16)
            .shadow(radius: 10)
            .frame(width: 350, height: 400)

            // Confirmation dialog
            if showingConfirmation {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Text("Add to Shopping List?")
                            .font(.headline)

                        Text("\(quantity) \(unit) of \(itemName)")
                            .font(.body)
                            .padding(.vertical, 5)

                        HStack(spacing: 40) {
                            Button("Cancel") {
                                showingConfirmation = false
                                voiceAssistant.processingCommand = false
                            }
                            .foregroundColor(.red)

                            Button("Add") {
                                viewModel.addShoppingItem(name: itemName, quantity: quantity)
                                showingConfirmation = false
                                voiceAssistant.processingCommand = false

                                // Show success feedback
                                feedbackMessage =
                                    "Added \(quantity) \(unit) of \(itemName) to your shopping list"
                                showFeedback = true

                                // Dismiss after a delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    dismiss()
                                }
                            }
                            .foregroundColor(Color("ActionColor"))
                            .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(Color("CardColor"))
                    .cornerRadius(16)
                    .shadow(radius: 5)
                    .frame(width: 300, height: 150)
                    .transition(.opacity)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            voiceAssistant.onTextRecognized = { (text: String) in
                let (name, qty, unitValue) = voiceAssistant.processCommand(text)

                // Only show confirmation if we extracted a valid item name
                if !name.isEmpty {
                    itemName = name
                    quantity = qty
                    unit = unitValue
                    showingConfirmation = true
                } else {
                    // Show feedback that we couldn't understand
                    feedbackMessage = "Sorry, I couldn't understand that. Please try again."
                    showFeedback = true
                    voiceAssistant.processingCommand = false
                }
            }
        }
    }
}

#if DEBUG
    struct VoiceAssistantView_Previews: PreviewProvider {
        static var previews: some View {
            VoiceAssistantView(viewModel: KitchenViewModel())
        }
    }
#endif
