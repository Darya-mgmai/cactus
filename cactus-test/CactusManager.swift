//
//  CactusManager.swift
//  cactus-test
//
//  Created by Darya on 8/23/25.
//

import Foundation
import SwiftUI

// Chat message model
struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
}

// Cactus manager class
class CactusManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isModelLoaded = false
    @Published var currentModelName = "No Model"
    @Published var availableModels: [String] = []
    @Published var contextSize = "Unknown"
    @Published var modelParameters = "Unknown"
    
            // Settings
        private var currentContextSize = 4096  // Increased for Gemma 3
        private var currentTemperature = 0.8   // Slightly higher for more creative responses
        private var currentTopK = 40
        private var currentTopP = 0.9
        private var currentMaxTokens = 512     // Increased for more detailed responses
        private var currentThreads = 4
    
    private var cactusContext: cactus_context_handle_t?
    @Published var isGenerating = false
    private var shouldStopGeneration = false
    
    init() {
        setupAvailableModels()
        addWelcomeMessage()
    }
    
    private func setupAvailableModels() {
        // Add some example models - in a real app, these would be discovered from the model directory
        availableModels = [
            "Model 1",
            "Model 2"
        ]
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            id: UUID(),
            text: "Welcome to Magma AI! 🔥\n\nTap the gear icon to select a model and configure settings, then start chatting!",
            isUser: false,
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }
    
    func initializeCactus() {
        // Add this guard to prevent re-loading
        guard !isModelLoaded else { return }

        print("Initializing Cactus framework...")
        
        // Try to load the first available model
        if !availableModels.isEmpty {
            let firstModel = availableModels.first!
            print("Loading first available model: \(firstModel)")
            loadModel(firstModel)
        } else {
            print("No models available in app bundle")
            addSystemMessage("No model files found. Please add model files to the app bundle.")
        }
    }
    
    func loadModel(_ modelName: String) {
        print("Loading model: \(modelName) (will reload even if already loaded to apply new system prompt)")
        
        guard let modelPath = getModelPath(modelName) else {
            addSystemMessage("Model file not found: \(modelName)")
            return
        }
        
        addSystemMessage("Loading model: \(modelName)...")
        
        // Create initialization parameters and ensure proper string handling
        modelPath.withCString { modelPathCStr in
            var initParams = cactus_init_params_c_t()
            initParams.model_path = modelPathCStr
            initParams.chat_template = nil // Use default
        initParams.n_ctx = Int32(currentContextSize)
        initParams.n_batch = 512
        initParams.n_ubatch = 512
        initParams.n_gpu_layers = 0 // CPU only for demo
        initParams.n_threads = Int32(currentThreads)
        initParams.use_mmap = true
        initParams.use_mlock = false
        initParams.embedding = false
        initParams.pooling_type = 0
        initParams.embd_normalize = 0
        initParams.flash_attn = false
        initParams.cache_type_k = nil
        initParams.cache_type_v = nil
        initParams.progress_callback = { progress in
            print("Loading progress: \(progress * 100)%")
        }
        
            // Initialize context
            cactusContext = cactus_init_context_c(&initParams)
            
            if cactusContext != nil {
                DispatchQueue.main.async {
                    self.isModelLoaded = true
                    self.currentModelName = modelName
                    self.contextSize = "\(self.currentContextSize)"
                    self.modelParameters = "Variable"
                    self.addSystemMessage("✅ Model loaded successfully!")
                }
            } else {
                DispatchQueue.main.async {
                    self.addSystemMessage("❌ Failed to load model: \(modelName)")
                }
            }
        }
    }
    
    func generateResponse(to message: String, completion: @escaping (Bool) -> Void) {
        guard let context = cactusContext, isModelLoaded else {
            addSystemMessage("No model loaded. Please select a model first.")
            completion(false)
            return
        }
        
        // Check if generation was stopped before starting
        guard !shouldStopGeneration else {
            completion(false)
            return
        }
        
        isGenerating = true
        shouldStopGeneration = false
        
        let history = self.messages
        let userMessage = ChatMessage(id: UUID(), text: message, isUser: true, timestamp: Date())
        addMessage(userMessage)
        
        // Format the prompt based on the current model
        let formattedPrompt = formatPromptForModel(history: history, newUserMessage: message, modelName: currentModelName)
        
        // Debug: Print the prompt being sent to the model
        print("🔍 Sending prompt to model:")
        print("Current model name: \(currentModelName)")
        print("Length: \(formattedPrompt.count) characters")
        print("=== PROMPT START ===")
        print(formattedPrompt)
        print("=== PROMPT END ===")
        print("🔍 History contains \(history.count) messages")
        
        // CORRECTED STRUCTURE: Start the background task FIRST
        DispatchQueue.global(qos: .userInitiated).async {
            // Capture the user message for use in the background task
            let userMessage = message
            
            // Now, perform all C-interop inside this background task
            formattedPrompt.withCString { promptCStr in
                var completionParams = cactus_completion_params_c_t()
                completionParams.prompt = promptCStr // This pointer is now valid
                completionParams.n_predict = Int32(self.currentMaxTokens)
                completionParams.n_threads = Int32(self.currentThreads)
                completionParams.seed = -1
                completionParams.temperature = self.currentTemperature
                completionParams.top_k = Int32(self.currentTopK)
                completionParams.top_p = self.currentTopP
                completionParams.min_p = 0.1
                completionParams.typical_p = 1.0
                completionParams.penalty_last_n = 64
                completionParams.penalty_repeat = 1.1
                completionParams.penalty_freq = 0.0
                completionParams.penalty_present = 0.0
                completionParams.mirostat = 0
                completionParams.mirostat_tau = 5.0
                completionParams.mirostat_eta = 0.1
                completionParams.ignore_eos = false
                completionParams.n_probs = 0
                completionParams.grammar = nil
                completionParams.token_callback = nil
                
                // Use appropriate stop sequence based on model
                let stopSequence = self.currentModelName.hasPrefix("Qwen") ? "<|im_end|>" : "<end_of_turn>"
                stopSequence.withCString { stopCStr in
                    var stopSequences: [UnsafePointer<CChar>?] = [stopCStr]
                    stopSequences.withUnsafeMutableBufferPointer { bufferPointer in
                        completionParams.stop_sequences = bufferPointer.baseAddress
                        completionParams.stop_sequence_count = 1
                        
                        // Check if generation was stopped before making the C call
                        guard !self.shouldStopGeneration else {
                            DispatchQueue.main.async {
                                self.isGenerating = false
                                completion(false)
                            }
                            return
                        }
                        
                        // The C call is now synchronous within this background thread,
                        // which is safe because all pointers are valid.
                        var result = cactus_completion_result_c_t()
                        let status = cactus_completion_c(context, &completionParams, &result)
                        
                        // Switch back to the main thread to update the UI
                        DispatchQueue.main.async {
                            self.isGenerating = false
                            
                                                    if status == 0 && result.text != nil {
                            let rawResponse = String(cString: result.text)
                            print("🔍 Raw model response (\(rawResponse.count) chars):\n\(rawResponse)\n🔍 End of response")
                            
                            // Clean the response: remove stop sequences and trim whitespace
                            var cleanedResponse = rawResponse
                                .replacingOccurrences(of: "<end_of_turn>", with: "")
                                .replacingOccurrences(of: "<|im_end|>", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Remove common artifacts at the beginning of responses
                            cleanedResponse = cleanedResponse.replacingOccurrences(of: "^[!*]+\\s*", with: "", options: .regularExpression)
                            
                            // Additional cleaning for common artifacts
                            cleanedResponse = cleanedResponse.replacingOccurrences(of: "^\\s*[!*]+\\s*", with: "", options: .regularExpression)
                            
                            // Remove the user's message if it appears at the beginning
                            if cleanedResponse.hasPrefix(userMessage) {
                                cleanedResponse = String(cleanedResponse.dropFirst(userMessage.count))
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            // If response is empty after cleaning, provide a fallback
                            if cleanedResponse.isEmpty {
                                cleanedResponse = "I apologize, but I couldn't generate a proper response. Please try rephrasing your question."
                            }
                            
                            print("🔍 Cleaned response (\(cleanedResponse.count) chars):\n\(cleanedResponse)\n🔍 End cleaned response")
                            let aiMessage = ChatMessage(id: UUID(), text: cleanedResponse, isUser: false, timestamp: Date())
                            self.addMessage(aiMessage)
                            cactus_free_completion_result_members_c(&result)
                            completion(true)
                            } else {
                                print("❌ Model generation failed with status: \(status)")
                                self.addSystemMessage("❌ Failed to generate response (status: \(status))")
                                completion(false)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func stopGeneration() {
        print("🛑 Stop generation called - isGenerating: \(isGenerating)")
        
        // Add a message to indicate generation was stopped if we were generating
        if isGenerating {
            addSystemMessage("🛑 Generation stopped by user")
        }
        
        shouldStopGeneration = true
        isGenerating = false
        
        print("🛑 Stop generation completed - shouldStopGeneration: \(shouldStopGeneration), isGenerating: \(isGenerating)")
    }
    
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }
    
    func clearMessages() {
        print("🧹 clearMessages() called - current message count: \(messages.count)")
        DispatchQueue.main.async {
            self.messages.removeAll()
            print("🧹 Messages cleared - new count: \(self.messages.count)")
            self.addWelcomeMessage()
            print("🧹 Welcome message added - final count: \(self.messages.count)")
        }
    }
    
    func updateSettings(
        contextSize: Int,
        temperature: Double,
        topK: Int,
        topP: Double,
        maxTokens: Int,
        threads: Int
    ) {
        currentContextSize = contextSize
        currentTemperature = temperature
        currentTopK = topK
        currentTopP = topP
        currentMaxTokens = maxTokens
        currentThreads = threads
        
        // Update published properties
        self.contextSize = "\(contextSize)"
        
        addSystemMessage("Settings updated successfully!")
    }
    
    private func addSystemMessage(_ text: String) {
        let systemMessage = ChatMessage(
            id: UUID(),
            text: text,
            isUser: false,
            timestamp: Date()
        )
        messages.append(systemMessage)
    }
    
    // Format prompt based on the model type
    private func formatPromptForModel(history: [ChatMessage], newUserMessage: String, modelName: String) -> String {
        if modelName == "Model 2" {
            // Model 2 is Qwen2.5-1.5B-Instruct
            return formatPromptForQwen(history: history, newUserMessage: newUserMessage, modelName: modelName)
        } else {
            // Model 1 is Gemma3-1B
            return formatPromptForGemma3(history: history, newUserMessage: newUserMessage, modelName: modelName)
        }
    }
    
    // Format prompt for Qwen models
    private func formatPromptForQwen(history: [ChatMessage], newUserMessage: String, modelName: String) -> String {
        var prompt = ""
        let systemPrompt = "You are \(modelName), a helpful AI assistant. If someone asks for your name, respond that you are \(modelName). Provide clear, accurate, and informative responses."
        
        // Add system message
        prompt += "<|im_start|>system\n\(systemPrompt)<|im_end|>\n"
        
        // Add the chat history
        for message in history {
            // Filter out non-chat messages
            if message.text.contains("Welcome to Magma AI!") || 
               message.text.contains("Settings updated") || 
               message.text.contains("Model loaded") {
                continue
            }
            
            if message.isUser {
                prompt += "<|im_start|>user\n\(message.text)<|im_end|>\n"
            } else {
                prompt += "<|im_start|>assistant\n\(message.text)<|im_end|>\n"
            }
        }
        
        // Add the new user message
        prompt += "<|im_start|>user\n\(newUserMessage)<|im_end|>\n"
        prompt += "<|im_start|>assistant\n"
        
        return prompt
    }
    
    // Format prompt for Gemma 3 Instruct model
    private func formatPromptForGemma3(history: [ChatMessage], newUserMessage: String, modelName: String) -> String {
        var prompt = ""
        let systemPrompt = "You are \(modelName), a knowledgeable AI assistant. If someone asks for your name, respond that you are \(modelName). When users ask questions, provide specific, detailed, and informative answers. Do not ask follow-up questions or say 'I'm ready for questions' - just answer directly with facts and information. Always respond in English with concrete details."

        // Add the chat history to the prompt
        for message in history {
            // Filter out non-chat messages and generic/repeated responses
            if message.text.contains("Welcome to Magma AI!") || 
               message.text.contains("Settings updated") || 
               message.text.contains("Model loaded") ||
               message.text.contains("Okay, I'm ready for your question!") ||
               message.text.contains("Tell me what you want to know") {
                continue
            }
            
            if message.isUser {
                prompt += "<start_of_turn>user\n\(message.text)<end_of_turn>\n"
            } else {
                prompt += "<start_of_turn>model\n\(message.text)<end_of_turn>\n"
            }
        }

        // For the new user message, prepend the system prompt ONLY if this is the first real message
        let isFirstUserMessage = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isFirstUserMessage {
            prompt += "<start_of_turn>user\n\(systemPrompt)\n\n\(newUserMessage)<end_of_turn>\n"
        } else {
            prompt += "<start_of_turn>user\n\(newUserMessage)<end_of_turn>\n"
        }
        
        // Signal for the model to start its response
        prompt += "<start_of_turn>model\n"
        
        return prompt
    }
    
    private func getModelPath(_ modelName: String) -> String? {
        // Handle the display names by mapping to the actual files
        let actualFileName: String
        if modelName == "Model 1" {
            actualFileName = "gemma-3-1b-it-q4_k_m.gguf"
        } else if modelName == "Model 2" {
            actualFileName = "qwen2.5-1.5b-instruct-q8_0.gguf"
        } else {
            actualFileName = modelName
        }
        
        // First check app bundle
        let resourceName = actualFileName.replacingOccurrences(of: ".gguf", with: "")
        if let bundlePath = Bundle.main.path(forResource: resourceName, ofType: "gguf") {
            print("Found model in bundle: \(bundlePath)")
            return bundlePath
        }
        
        // Also try with the full name as resource
        if let bundlePath = Bundle.main.path(forResource: actualFileName, ofType: nil) {
            print("Found model in bundle with full name: \(bundlePath)")
            return bundlePath
        }
        
        // Then check documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let modelURL = documentsPath?.appendingPathComponent(actualFileName)
        
        if let modelURL = modelURL, FileManager.default.fileExists(atPath: modelURL.path) {
            print("Found model in documents: \(modelURL.path)")
            return modelURL.path
        }
        
        // Check if file exists in main bundle directly
        if let bundlePath = Bundle.main.path(forResource: actualFileName, ofType: "") {
            print("Found model in bundle root: \(bundlePath)")
            return bundlePath
        }
        
        print("Model not found: \(modelName) (tried \(actualFileName))")
        print("Bundle resource path: \(Bundle.main.bundlePath)")
        print("Available bundle resources: \(Bundle.main.paths(forResourcesOfType: "gguf", inDirectory: nil))")
        
        return nil
    }
    
    deinit {
        if let context = cactusContext {
            cactus_free_context_c(context)
        }
    }
} 