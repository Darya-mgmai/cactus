//
//  ContentView.swift
//  cactus-test
//
//  Created by Darya on 8/23/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cactusManager = CactusManager()
    @State private var inputText = ""
    @State private var showingModelPicker = false
    @State private var showingSettings = false
    
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
                            Text("Cactus AI Demo")
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
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: {
                                showingModelPicker = true
                            }) {
                                Image(systemName: "gear")
                                    .foregroundColor(.blue)
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
                        
                        Button(action: sendMessage) {
                            Image(systemName: cactusManager.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(cactusManager.isGenerating ? .red : .blue)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cactusManager.isGenerating)
                    }
                    
                    if cactusManager.isGenerating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Generating response...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
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
}

struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing) {
                    Text(message.text)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading) {
                    Text(message.text)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                                    .foregroundColor(.green)
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
