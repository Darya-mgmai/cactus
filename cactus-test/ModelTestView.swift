//
//  ModelTestView.swift
//  cactus-test
//
//  Created by Darya on 8/23/25.
//

import SwiftUI

struct ModelTestView: View {
    @State private var testResults: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Model Loading Test")
                    .font(.title)
                    .padding()
                
                Button("Test Model Loading") {
                    testModelLoading()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView("Testing...")
                        .padding()
                }
                
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(testResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.vertical, 2)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
        }
    }
    
    private func testModelLoading() {
        isLoading = true
        testResults.removeAll()
        
        addResult("🔍 Starting model loading test...")
        
        // Test 1: Check bundle path
        addResult("📁 Bundle path: \(Bundle.main.bundlePath)")
        
        // Test 2: List all files in bundle
        do {
            let bundleContents = try FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath)
            addResult("📋 Bundle contents: \(bundleContents.count) items")
            for item in bundleContents.sorted() {
                addResult("  - \(item)")
            }
        } catch {
            addResult("❌ Error reading bundle: \(error)")
        }
        
        // Test 3: Try different model search methods
        testModelPaths()
        
        // Test 4: Test model file properties
        testModelFileProperties()
        
        // Test 5: Try to initialize cactus with different paths
        testCactusInitialization()
        
        isLoading = false
    }
    
    private func testModelPaths() {
        addResult("\n🔍 Testing model path resolution...")
        
        let possiblePaths = [
            Bundle.main.path(forResource: "model", ofType: "gguf"),
            Bundle.main.path(forResource: "model.gguf", ofType: nil),
            Bundle.main.path(forResource: "model.gguf", ofType: "")
        ]
        
        for (index, path) in possiblePaths.enumerated() {
            if let path = path {
                addResult("✅ Method \(index + 1): Found at \(path)")
                testFileExistence(path)
            } else {
                addResult("❌ Method \(index + 1): Not found")
            }
        }
    }
    
    private func testFileExistence(_ path: String) {
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: path)
        addResult("   File exists: \(exists)")
        
        if exists {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: path)
                let size = attributes[.size] as? Int64 ?? 0
                addResult("   File size: \(size) bytes (\(ByteCountFormatter().string(fromByteCount: size)))")
                
                let url = URL(fileURLWithPath: path)
                let resourceValues = try url.resourceValues(forKeys: [.isReadableKey, .fileSizeKey])
                addResult("   Readable: \(resourceValues.isReadable ?? false)")
                addResult("   Size (URL): \(resourceValues.fileSize ?? 0) bytes")
            } catch {
                addResult("   ❌ Error getting file info: \(error)")
            }
        }
    }
    
    private func testModelFileProperties() {
        addResult("\n🔍 Testing model file properties...")
        
        if let modelPath = Bundle.main.path(forResource: "model", ofType: "gguf") {
            addResult("📄 Model path: \(modelPath)")
            
            // Test file header
            testFileHeader(modelPath)
        } else {
            addResult("❌ Could not find model file in bundle")
        }
    }
    
    private func testFileHeader(_ path: String) {
        do {
            let fileHandle = FileHandle(forReadingAtPath: path)
            if let fileHandle = fileHandle {
                let headerData = fileHandle.readData(ofLength: 32)
                fileHandle.closeFile()
                
                let headerHex = headerData.map { String(format: "%02x", $0) }.joined(separator: " ")
                addResult("📋 File header (32 bytes): \(headerHex)")
                
                // Check for GGUF magic number (should be "GGUF" = 0x47475546)
                if headerData.count >= 4 {
                    let magic = headerData.prefix(4)
                    let magicString = String(data: magic, encoding: .ascii) ?? "unknown"
                    addResult("🔮 Magic bytes: '\(magicString)'")
                    
                    if magicString == "GGUF" {
                        addResult("✅ Valid GGUF file detected!")
                    } else {
                        addResult("⚠️  Unexpected magic bytes (expected 'GGUF')")
                    }
                }
            } else {
                addResult("❌ Could not open file for reading")
            }
        } catch {
            addResult("❌ Error reading file header: \(error)")
        }
    }
    
    private func testCactusInitialization() {
        addResult("\n🔍 Testing Cactus initialization...")
        
        guard let modelPath = Bundle.main.path(forResource: "model", ofType: "gguf") else {
            addResult("❌ No model path found for testing")
            return
        }
        
        addResult("🚀 Attempting to initialize Cactus with: \(modelPath)")
        
        modelPath.withCString { modelPathCStr in
            var initParams = cactus_init_params_c_t()
            initParams.model_path = modelPathCStr
            initParams.chat_template = nil
            initParams.n_ctx = 512 // Small context for testing
            initParams.n_batch = 512
            initParams.n_ubatch = 512
            initParams.n_gpu_layers = 0
            initParams.n_threads = 2
            initParams.use_mmap = true
            initParams.use_mlock = false
            initParams.embedding = false
            initParams.pooling_type = 0
            initParams.embd_normalize = 0
            initParams.flash_attn = false
            initParams.cache_type_k = nil
            initParams.cache_type_v = nil
            
            addResult("📊 Init params configured")
            addResult("  - Context size: \(initParams.n_ctx)")
            addResult("  - Threads: \(initParams.n_threads)")
            addResult("  - Use mmap: \(initParams.use_mmap)")
            
            let context = cactus_init_context_c(&initParams)
            
            if context != nil {
                addResult("✅ Cactus context created successfully!")
                cactus_free_context_c(context)
                addResult("🧹 Context freed")
            } else {
                addResult("❌ Failed to create Cactus context")
                addResult("💡 This could indicate:")
                addResult("  - Model file is corrupted")
                addResult("  - Insufficient memory")
                addResult("  - Model format not supported")
                addResult("  - File permissions issue")
            }
        }
    }
    
    private func addResult(_ message: String) {
        DispatchQueue.main.async {
            self.testResults.append(message)
            print("[ModelTest] \(message)")
        }
    }
}

#Preview {
    ModelTestView()
} 