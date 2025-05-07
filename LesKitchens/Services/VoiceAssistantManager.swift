import Foundation
import Speech

#if os(iOS)
    import AVFoundation
#endif

// Voice Assistant Manager for handling speech recognition
class VoiceAssistantManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var errorMessage: String?
    @Published var processingCommand = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    #if os(iOS)
        private let audioEngine = AVAudioEngine()
    #endif

    private var silenceTimer: Timer?
    private var lastTranscriptionTime = Date()
    private let silenceThreshold: TimeInterval = 1.5  // Seconds of silence to consider speech finished

    var onTextRecognized: ((String) -> Void)?

    override init() {
        super.init()
        requestPermission()
    }

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.errorMessage = nil
                case .denied:
                    self.errorMessage = "Speech recognition permission denied"
                case .restricted, .notDetermined:
                    self.errorMessage = "Speech recognition not available"
                @unknown default:
                    self.errorMessage = "Unknown authorization status"
                }
            }
        }
    }

    func startListening() {
        guard !isListening else { return }

        // Check authorization
        guard speechRecognizer?.isAvailable == true else {
            errorMessage = "Speech recognition is not available"
            return
        }

        // Reset state
        recognizedText = ""
        errorMessage = nil
        processingCommand = false

        #if os(iOS)
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
                return
            }

            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                errorMessage = "Unable to create speech recognition request"
                return
            }
            recognitionRequest.shouldReportPartialResults = true

            // Configure audio input
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            // Start audio engine
            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
                return
            }

            // Start recognition task
            lastTranscriptionTime = Date()
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) {
                [weak self] result, error in
                guard let self = self else { return }

                var isFinal = false

                if let result = result {
                    // Update recognized text
                    DispatchQueue.main.async {
                        self.recognizedText = result.bestTranscription.formattedString
                    }

                    // Update last transcription time
                    self.lastTranscriptionTime = Date()
                    isFinal = result.isFinal

                    // If we have a final result, process it
                    if isFinal {
                        DispatchQueue.main.async {
                            self.processingCommand = true
                            self.onTextRecognized?(self.recognizedText)
                            self.stopListening()
                        }
                    }
                }

                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Recognition error: \(error.localizedDescription)"
                        self.stopListening()
                    }
                }
            }

            // Start silence detection timer
            startSilenceTimer()

            isListening = true
        #else
            // macOS implementation would go here
            errorMessage = "Voice recognition is only available on iOS devices"
        #endif
    }

    private func startSilenceTimer() {
        // Cancel any existing timer
        silenceTimer?.invalidate()

        // Create a new timer that checks for silence
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isListening else { return }

            let currentTime = Date()
            let timeSinceLastTranscription = currentTime.timeIntervalSince(
                self.lastTranscriptionTime)

            // If we've been silent for the threshold time and have some text, process it
            if timeSinceLastTranscription > self.silenceThreshold && !self.recognizedText.isEmpty {
                DispatchQueue.main.async {
                    print("Silence detected, processing command: \(self.recognizedText)")
                    self.processingCommand = true
                    self.onTextRecognized?(self.recognizedText)
                    self.stopListening()
                }
            }
        }
    }

    func stopListening() {
        // Stop silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil

        #if os(iOS)
            // Stop audio engine and recognition
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()

            // Reset audio session
            do {
                try AVAudioSession.sharedInstance().setActive(
                    false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
        #endif

        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    func processCommand(_ text: String) -> (String, Int, String) {
        let lowercasedText = text.lowercased()

        // Extract quantity
        var quantity = 1
        var unit = "each"

        // First check for numeric quantities (e.g., "2 pounds")
        let numericQuantityPattern =
            "\\b(\\d+)\\s+(pounds?|lbs?|ounces?|oz|bottles?|cups?|tablespoons?|teaspoons?|tbsp|tsp|pieces?|kilos?|grams?|kg|g)\\b"
        if let range = lowercasedText.range(of: numericQuantityPattern, options: .regularExpression)
        {
            let quantityMatch = String(lowercasedText[range])
            let components = quantityMatch.components(separatedBy: .whitespaces)

            if components.count >= 2 {
                // Get the numeric value
                if let numericValue = Int(components[0]) {
                    quantity = numericValue
                }

                // Get the unit
                let unitWord = components[1]
                if unitWord.contains("pound") || unitWord.contains("lb") {
                    unit = "lb"
                } else if unitWord.contains("ounce") || unitWord.contains("oz") {
                    unit = "oz"
                } else if unitWord.contains("bottle") {
                    unit = "bottle"
                } else if unitWord.contains("cup") {
                    unit = "cup"
                } else if unitWord.contains("tablespoon") || unitWord.contains("tbsp") {
                    unit = "tbsp"
                } else if unitWord.contains("teaspoon") || unitWord.contains("tsp") {
                    unit = "tsp"
                } else if unitWord.contains("kilo") || unitWord.contains("kg") {
                    unit = "kg"
                } else if unitWord.contains("gram") || unitWord.contains("g") {
                    unit = "g"
                }
            }
        } else {
            // Check for word-based quantities (e.g., "two pounds")
            let numberWords = [
                "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
                "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            ]

            for (word, value) in numberWords {
                let wordQuantityPattern =
                    "\\b\(word)\\s+(pounds?|lbs?|ounces?|oz|bottles?|cups?|tablespoons?|teaspoons?|tbsp|tsp|pieces?|kilos?|grams?|kg|g)\\b"

                if let range = lowercasedText.range(
                    of: wordQuantityPattern, options: .regularExpression)
                {
                    quantity = value

                    let unitMatch = String(lowercasedText[range])
                        .replacingOccurrences(of: word, with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if unitMatch.contains("pound") || unitMatch.contains("lb") {
                        unit = "lb"
                    } else if unitMatch.contains("ounce") || unitMatch.contains("oz") {
                        unit = "oz"
                    } else if unitMatch.contains("bottle") {
                        unit = "bottle"
                    } else if unitMatch.contains("cup") {
                        unit = "cup"
                    } else if unitMatch.contains("tablespoon") || unitMatch.contains("tbsp") {
                        unit = "tbsp"
                    } else if unitMatch.contains("teaspoon") || unitMatch.contains("tsp") {
                        unit = "tsp"
                    } else if unitMatch.contains("kilo") || unitMatch.contains("kg") {
                        unit = "kg"
                    } else if unitMatch.contains("gram") || unitMatch.contains("g") {
                        unit = "g"
                    }

                    break
                }
            }
        }

        // Extract item name
        var itemName = ""

        // Common patterns with prepositions: "add 2 pounds of beef"
        let prepositions = ["of", "for", "some"]
        for preposition in prepositions {
            let pattern = "\\b\(preposition)\\s+([\\w\\s]+?)(?:\\s+in|\\s+to|\\s+on|$)"
            if let range = lowercasedText.range(of: pattern, options: .regularExpression) {
                let match = String(lowercasedText[range])
                let components = match.components(separatedBy: "\(preposition) ")
                if components.count > 1 {
                    itemName = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    // Remove trailing "in", "to", "on" if present
                    if let endRange = itemName.range(
                        of: "\\s+(in|to|on)$", options: .regularExpression)
                    {
                        itemName = String(itemName[..<endRange.lowerBound])
                    }
                    break
                }
            }
        }

        // If no preposition found, try to extract item directly after quantity
        if itemName.isEmpty {
            // Remove quantity and unit from the text to get the item name
            var processedText = lowercasedText

            // Remove numeric quantity pattern
            if let range = processedText.range(
                of: numericQuantityPattern, options: .regularExpression)
            {
                let match = String(processedText[range])
                processedText = processedText.replacingOccurrences(of: match, with: "")
            }

            // Remove word-based quantity patterns
            for (word, _) in [
                "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
                "eight": 8, "nine": 9, "ten": 10,
            ] {
                let wordPattern =
                    "\\b\(word)\\s+(pounds?|lbs?|ounces?|oz|bottles?|cups?|tablespoons?|teaspoons?|tbsp|tsp|pieces?|kilos?|grams?|kg|g)\\b"
                if let range = processedText.range(of: wordPattern, options: .regularExpression) {
                    let match = String(processedText[range])
                    processedText = processedText.replacingOccurrences(of: match, with: "")
                }
            }

            // Remove action verbs and common words
            let wordsToRemove = [
                "add", "buy", "get", "put", "to", "in", "my", "shopping", "list", "the", "some",
            ]
            for word in wordsToRemove {
                processedText = processedText.replacingOccurrences(
                    of: "\\b\(word)\\b", with: "", options: .regularExpression)
            }

            // Clean up and set as item name
            itemName = processedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Clean up item name - remove multiple spaces
        while itemName.contains("  ") {
            itemName = itemName.replacingOccurrences(of: "  ", with: " ")
        }

        return (itemName, quantity, unit)
    }
}
