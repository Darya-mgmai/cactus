//
//  ContentView.swift
//  cactus-test
//
//  Created by Darya on 8/23/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cactusManager = CactusManager()
    @StateObject private var speechManager = SpeechManager()
    @State private var inputText = ""
    @State private var showingModelPicker = false
    @State private var showingSettings = false
    
    // Custom theme colors
    private var accentColor: Color {
        Color(red: 0.7, green: 0.6, blue: 0.8) // Light purple/lavender
    }
    
    private var darkBackground: Color {
        Color(red: 0.2, green: 0.25, blue: 0.3) // Dark blue-gray
    }
    
    private var cardBackground: Color {
        Color(red: 0.25, green: 0.3, blue: 0.35) // Slightly lighter blue-gray
    }
    
    var body: some View {
        TabView {
            chatView
                .tabItem {
                    Image(systemName: "message")
                        .foregroundColor(accentColor)
                    Text("Chat")
                        .foregroundColor(accentColor)
                }
            
            ModelTestView()
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(.gray)
                    Text("Debug")
                        .foregroundColor(.gray)
                }
        }
    }
    
    private var chatView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with model info
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("WV Expert Agent")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(cactusManager.currentModelName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button(action: {
                                showingSettings = true
                            }) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(accentColor)
                            }
                            
                            Button(action: {
                                showingModelPicker = true
                            }) {
                                CompanyLogoView()
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                    .padding()
                    
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(cactusManager.isModelLoaded ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(cactusManager.isModelLoaded ? "Model Ready" : "No Model Loaded")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal)
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
                        TextField("Type your message...", text: $inputText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(cactusManager.isGenerating)
                        
                        // Microphone button for speech-to-text
                        Button(action: toggleRecording) {
                            Image(systemName: speechManager.isRecording ? "mic.fill" : "mic")
                                .font(.title2)
                                .foregroundColor(speechManager.isRecording ? .red : accentColor)
                        }
                        .disabled(cactusManager.isGenerating || !speechManager.hasPermission)
                        
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
        .sheet(isPresented: $showingModelPicker) {
            ModelPickerView(cactusManager: cactusManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(cactusManager: cactusManager)
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
}

struct MessageView: View {
    let message: ChatMessage
    @ObservedObject var speechManager: SpeechManager
    
    // Custom theme colors
    private var accentColor: Color {
        Color(red: 0.7, green: 0.6, blue: 0.8) // Light purple/lavender
    }
    
    private var darkBackground: Color {
        Color(red: 0.2, green: 0.25, blue: 0.3) // Dark blue-gray
    }
    
    private var cardBackground: Color {
        Color(red: 0.25, green: 0.3, blue: 0.35) // Slightly lighter blue-gray
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
    
    // Custom theme colors
    private var accentColor: Color {
        Color(red: 0.7, green: 0.6, blue: 0.8) // Light purple/lavender
    }
    
    private var darkBackground: Color {
        Color(red: 0.2, green: 0.25, blue: 0.3) // Dark blue-gray
    }
    
    private var cardBackground: Color {
        Color(red: 0.25, green: 0.3, blue: 0.35) // Slightly lighter blue-gray
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
            // Black rounded square background
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.2, green: 0.25, blue: 0.3))
                .frame(width: 16, height: 16)
            
            // Red quarter circle in top-left
            VStack {
                HStack {
                    Circle()
                        .fill(Color(red: 0.7, green: 0.6, blue: 0.8))
                        .frame(width: 8, height: 8)
                        .clipShape(
                            Rectangle()
                                .size(width: 4, height: 4)
                        )
                        .offset(x: -2, y: -2)
                    Spacer()
                }
                Spacer()
            }
            .frame(width: 16, height: 16)
        }
    }
}

#Preview {
    ContentView()
}
