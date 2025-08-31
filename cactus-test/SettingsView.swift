//
//  SettingsView.swift
//  cactus-test
//
//  Created by Darya on 8/23/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var cactusManager: CactusManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var contextSize = 2048
    @State private var temperature = 0.7
    @State private var topK = 40
    @State private var topP = 0.9
    @State private var maxTokens = 256
    @State private var threads = 4
    
    var body: some View {
        NavigationView {
            Form {
                Section("Gemma 3 Model Configuration") {
                    HStack {
                        Text("Context Size")
                        Spacer()
                        Text("\(contextSize)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(contextSize) },
                        set: { contextSize = Int($0) }
                    ), in: 512...8192, step: 512)
                    
                    HStack {
                        Text("Threads")
                        Spacer()
                        Text("\(threads)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(threads) },
                        set: { threads = Int($0) }
                    ), in: 1...8, step: 1)
                }
                
                Section("Generation Parameters") {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.2f", temperature))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                    
                    HStack {
                        Text("Top-K")
                        Spacer()
                        Text("\(topK)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(topK) },
                        set: { topK = Int($0) }
                    ), in: 1...100, step: 1)
                    
                    HStack {
                        Text("Top-P")
                        Spacer()
                        Text(String(format: "%.2f", topP))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $topP, in: 0.0...1.0, step: 0.05)
                    
                    HStack {
                        Text("Max Tokens")
                        Spacer()
                        Text("\(maxTokens)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(maxTokens) },
                        set: { maxTokens = Int($0) }
                    ), in: 64...1024, step: 64)
                }
                
                Section("System Information") {
                    InfoRow(title: "Device", value: UIDevice.current.model)
                    InfoRow(title: "iOS Version", value: UIDevice.current.systemVersion)
                    InfoRow(title: "Available Memory", value: getAvailableMemory())
                    InfoRow(title: "Cactus Version", value: "2.0")
                }
                
                Section("Model Information") {
                    InfoRow(title: "Current Model", value: cactusManager.currentModelName)
                    InfoRow(title: "Status", value: cactusManager.isModelLoaded ? "Loaded" : "Not Loaded")
                    InfoRow(title: "Context Size", value: cactusManager.contextSize)
                    InfoRow(title: "Parameters", value: cactusManager.modelParameters)
                }
                
                Section("Actions") {
                    Button("Reload Current Model") {
                        if !cactusManager.currentModelName.isEmpty && cactusManager.currentModelName != "No Model" {
                            cactusManager.loadModel(cactusManager.currentModelName)
                        }
                    }
                    .disabled(!cactusManager.isModelLoaded)
                    
                    Button("Clear Chat History") {
                        cactusManager.clearMessages()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        // Save settings to UserDefaults or update CactusManager
        UserDefaults.standard.set(contextSize, forKey: "contextSize")
        UserDefaults.standard.set(temperature, forKey: "temperature")
        UserDefaults.standard.set(topK, forKey: "topK")
        UserDefaults.standard.set(topP, forKey: "topP")
        UserDefaults.standard.set(maxTokens, forKey: "maxTokens")
        UserDefaults.standard.set(threads, forKey: "threads")
        
        // Update CactusManager with new settings
        cactusManager.updateSettings(
            contextSize: contextSize,
            temperature: temperature,
            topK: topK,
            topP: topP,
            maxTokens: maxTokens,
            threads: threads
        )
    }
    
    private func getAvailableMemory() -> String {
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory
        let memoryInGB = Double(physicalMemory) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", memoryInGB)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView(cactusManager: CactusManager())
} 