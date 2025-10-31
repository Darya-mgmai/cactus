//
//  ContentView.swift
//  cactus-test
//
//  Created by Darya on 8/23/25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var cactusManager = CactusManager()
    @StateObject private var speechManager = SpeechManager()
    @State private var inputText = ""
    @State private var showingDocumentPicker = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    
    // Simple theme colors
    private var accentColor: Color {
        Color.red // Red highlights
    }
    
    private var darkBackground: Color {
        Color(red: 0.2, green: 0.2, blue: 0.2) // Dark gray background
    }
    
    private var cardBackground: Color {
        Color(red: 0.3, green: 0.3, blue: 0.3) // Slightly lighter gray
    }
    
    var body: some View {
        chatView
    }
    
    private var chatView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with model info
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Magma AI")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(cactusManager.isModelLoaded ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, -16)
                }
                .background(darkBackground)
                
                Divider()
                
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(cactusManager.messages) { message in
                                MessageView(message: message, speechManager: speechManager)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: cactusManager.messages.count) { _ in
                        if let lastMessage = cactusManager.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input area
                VStack(spacing: 8) {
                    HStack {
                        // Plus button for attachments
                        Menu {
                            Button(action: { showingPhotoPicker = true }) {
                                Label("Photo", systemImage: "photo")
                            }
                            Button(action: { showingDocumentPicker = true }) {
                                Label("Document", systemImage: "doc")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(accentColor)
                        }
                        .disabled(cactusManager.isGenerating)
                        
                        ZStack(alignment: .trailing) {
                            TextField("Type your message...", text: $inputText, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(cactusManager.isGenerating)
                                .padding(.trailing, 40)
                            
                            // Mic inside the text field (hidden when typing text)
                            if inputText.isEmpty {
                                Button(action: toggleRecording) {
                                    Image(systemName: speechManager.isRecording ? "mic.fill" : "mic")
                                        .font(.title3)
                                        .foregroundColor(speechManager.isRecording ? .red : accentColor)
                                }
                                .disabled(cactusManager.isGenerating || !speechManager.hasPermission)
                                .padding(.trailing, 12)
                            }
                        }
                        
                        Button(action: sendMessage) {
                            Image(systemName: cactusManager.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(cactusManager.isGenerating ? .red : accentColor)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cactusManager.isGenerating)
                    }
                    
                    if cactusManager.isGenerating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                        }
                    }
                    
                    // Recording indicator
                    if speechManager.isRecording {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.red)
                            Text("Listening... \(speechManager.recordingText)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(2)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(darkBackground)
            }
            .navigationBarHidden(true)
        }
        .accentColor(accentColor)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
        .fileImporter(isPresented: $showingDocumentPicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            handleDocumentSelection(result)
        }
        .task {
            cactusManager.initializeCactus()
            
            // Set up automatic TTS for AI responses
            cactusManager.onAIMessageAdded = { responseText in
                // Only speak if it's not a system message
                if !responseText.contains("❌") && !responseText.contains("🛑") && !responseText.contains("Settings updated") {
                    // Add a small delay to ensure the message is displayed first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        speechManager.speak(responseText)
                    }
                }
            }
            
            // Set up STT callback to automatically send messages
            speechManager.onRecordingFinished = { [weak cactusManager] recordedText in
                guard let cactusManager = cactusManager else { return }
                DispatchQueue.main.async {
                    inputText = recordedText
                    // Automatically send the message
                    sendMessage()
                }
            }
        }
        .onChange(of: selectedPhoto) { _ in
            handlePhotoSelection()
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if cactusManager.isGenerating {
            // Stop generation
            cactusManager.stopGeneration()
        } else {
            // Send message - let generateResponse handle adding the message
            let messageToSend = inputText
            inputText = ""
            
            cactusManager.generateResponse(to: messageToSend) { success in
                // The isGenerating state is managed by CactusManager
            }
        }
    }
    
    // MARK: - Speech Functions
    private func toggleRecording() {
        if speechManager.isRecording {
            speechManager.stopRecording()
            // The callback will handle setting inputText and sending the message
        } else {
            // Clear any existing text and start recording
            speechManager.startRecording()
        }
    }
    
    // MARK: - Attachment Functions
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                print("Selected document: \(url.lastPathComponent)")
                // TODO: Process the document
            }
        case .failure(let error):
            print("Document selection failed: \(error)")
        }
    }
    
    private func handlePhotoSelection() {
        // TODO: Process selected photo
        if let photo = selectedPhoto {
            print("Selected photo: \(photo)")
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    @ObservedObject var speechManager: SpeechManager
    
    // Simple theme colors
    private var accentColor: Color {
        Color.red // Red highlights
    }
    
    private var darkBackground: Color {
        Color(red: 0.2, green: 0.2, blue: 0.2) // Dark gray background
    }
    
    private var cardBackground: Color {
        Color(red: 0.3, green: 0.3, blue: 0.3) // Slightly lighter gray
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing) {
                    Text(message.text)
                        .padding()
                        .background(accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                VStack(alignment: .leading) {
                    HStack {
                        Text(message.text)
                            .padding()
                            .background(cardBackground)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Speaker button for AI messages
                        Button(action: {
                            if speechManager.isPlaying {
                                speechManager.stopSpeaking()
                            } else {
                                speechManager.speak(message.text)
                            }
                        }) {
                            Image(systemName: speechManager.isPlaying ? "speaker.slash.fill" : "speaker.2.fill")
                                .font(.caption)
                                .foregroundColor(accentColor)
                        }
                        .padding(.leading, 4)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
        }
    }
}

struct ModelPickerView: View {
    @ObservedObject var cactusManager: CactusManager
    @Environment(\.dismiss) private var dismiss
    
    // Simple theme colors
    private var accentColor: Color {
        Color.red // Red highlights
    }
    
    private var darkBackground: Color {
        Color(red: 0.2, green: 0.2, blue: 0.2) // Dark gray background
    }
    
    private var cardBackground: Color {
        Color(red: 0.3, green: 0.3, blue: 0.3) // Slightly lighter gray
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Available Models") {
                    ForEach(cactusManager.availableModels, id: \.self) { model in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model)
                                    .font(.headline)
                                Text("Tap to load")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Spacer()
                            if cactusManager.currentModelName == model {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            cactusManager.loadModel(model)
                            dismiss()
                        }
                    }
                }
                
                Section("Model Info") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Model: \(cactusManager.currentModelName)")
                        Text("Status: \(cactusManager.isModelLoaded ? "Loaded" : "Not Loaded")")
                        if cactusManager.isModelLoaded {
                            Text("Context Size: \(cactusManager.contextSize)")
                            Text("Parameters: \(cactusManager.modelParameters)")
                        }
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Model Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CompanyLogoView: View {
    var body: some View {
        ZStack {
            // Black square background
            Rectangle()
                .fill(Color.black)
                .frame(width: 16, height: 16)
                .cornerRadius(2)
            
            // Red three-quarters circle
            Path { path in
                let center = CGPoint(x: 8, y: 8)
                let radius: CGFloat = 5
                
                // Start from top of circle
                path.move(to: CGPoint(x: center.x, y: center.y - radius))
                
                // Draw arc from top to left
                path.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: false)
                
                // Draw straight line to bottom
                path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                
                // Draw arc from bottom to right
                path.addArc(center: center, radius: radius, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: false)
                
                // Close the path
                path.closeSubpath()
            }
            .fill(Color.red)
        }
    }
}

#Preview {
    ContentView()
}
