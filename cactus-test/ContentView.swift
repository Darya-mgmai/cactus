//
//  ContentView.swift
//  cactus-test
//
//  Created by Darya on 8/23/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cactusManager = CactusManager()
    // @StateObject private var speechManager = SpeechManager()  // Temporarily disabled
    @State private var inputText = ""
    @State private var showingModelPicker = false
    @State private var showingSettings = false
    
    // Adaptive color that works across iOS versions
    private var adaptiveBlue: Color {
        Color(UIColor.systemBlue)
    }
    
    var body: some View {
        TabView {
            chatView
                .tabItem {
                    Image(systemName: "message")
                    Text("Chat")
                }
            
            ModelTestView()
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Debug")
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
                            Text(cactusManager.currentModelName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button(action: {
                                showingSettings = true
                            }) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(adaptiveBlue)
                            }
                            
                            Button(action: {
                                showingModelPicker = true
                            }) {
                                Image(systemName: "gear")
                                    .foregroundColor(adaptiveBlue)
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
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(cactusManager.messages) { message in
                                MessageView(message: message)
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
                        
                        // Microphone button for speech-to-text (DISABLED)
                        // Button(action: toggleRecording) {
                        //     Image(systemName: speechManager.isRecording ? "mic.fill" : "mic")
                        //         .font(.title2)
                        //         .foregroundColor(speechManager.isRecording ? .red : adaptiveBlue)
                        // }
                        // .disabled(cactusManager.isGenerating || !speechManager.hasPermission)
                        
                        Button(action: sendMessage) {
                            Image(systemName: cactusManager.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(cactusManager.isGenerating ? .red : adaptiveBlue)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cactusManager.isGenerating)
                    }
                    
                    if cactusManager.isGenerating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    // Recording indicator (DISABLED)
                    // if speechManager.isRecording {
                    //     HStack {
                    //         Image(systemName: "waveform")
                    //             .foregroundColor(.red)
                    //         Text("Listening... \(speechManager.recordingText)")
                    //             .font(.caption)
                    //             .foregroundColor(.secondary)
                    //             .lineLimit(2)
                    //         Spacer()
                    //     }
                    // }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingModelPicker) {
            ModelPickerView(cactusManager: cactusManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(cactusManager: cactusManager)
        }
        .task {
            cactusManager.initializeCactus()
            
            // Set up automatic TTS for AI responses (DISABLED)
            // cactusManager.onAIMessageAdded = { responseText in
            //     // Only speak if it's not a system message and permissions are granted
            //     if speechManager.hasPermission && 
            //        !responseText.contains("❌") && !responseText.contains("🛑") && !responseText.contains("Settings updated") {
            //         // speechManager.speak(responseText) // Temporarily disabled
            //         print("🔊 Would speak: \(responseText.prefix(50))...")
            //     }
            // }
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
    
    // MARK: - Speech Functions (DISABLED)
    // private func toggleRecording() {
    //     if speechManager.isRecording {
    //         speechManager.stopRecording()
    //         // Use the recorded text as input
    //         if !speechManager.recordingText.isEmpty {
    //             inputText = speechManager.recordingText
    //         }
    //     } else {
    //         // Clear any existing text and start recording
    //         speechManager.startRecording()
    //     }
    // }
}

struct MessageView: View {
    let message: ChatMessage
    // @ObservedObject var speechManager: SpeechManager  // Temporarily disabled
    
    // Adaptive color that works across iOS versions
    private var adaptiveBlue: Color {
        Color(UIColor.systemBlue)
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing) {
                    Text(message.text)
                        .padding()
                        .background(adaptiveBlue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading) {
                    HStack {
                        Text(message.text)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Speaker button for AI messages (DISABLED)
                        // Button(action: {
                        //     if speechManager.isPlaying {
                        //         speechManager.stopSpeaking()
                        //     } else {
                        //         speechManager.speak(message.text)
                        //     }
                        // }) {
                        //     Image(systemName: speechManager.isPlaying ? "speaker.slash.fill" : "speaker.2.fill")
                        //         .font(.caption)
                        //         .foregroundColor(adaptiveBlue)
                        // }
                        // .padding(.leading, 4)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
}

struct ModelPickerView: View {
    @ObservedObject var cactusManager: CactusManager
    @Environment(\.dismiss) private var dismiss
    
    // Adaptive color that works across iOS versions
    private var adaptiveBlue: Color {
        Color(UIColor.systemBlue)
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
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if cactusManager.currentModelName == model {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(adaptiveBlue)
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

#Preview {
    ContentView()
}
