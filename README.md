# Cactus AI Demo App

A comprehensive demo application showcasing the [Cactus framework](https://github.com/cactus-compute) for on-device AI. This app demonstrates how to run AI models locally on iOS devices without requiring internet connectivity.

## Features

- 🤖 **On-Device AI**: Run AI models completely offline
- 💬 **Chat Interface**: Interactive chat with AI models
- 🔄 **Model Switching**: Load different AI models dynamically
- 🚀 **Real-time Generation**: Stream responses from the AI
- 🔒 **Privacy-First**: All processing happens locally on your device
- 📱 **Native iOS**: Built with SwiftUI for optimal performance

## Getting Started

### Prerequisites

- Xcode 15.0 or later
- iOS 18.5 or later
- A .gguf model file (see Model Setup below)

### Installation

1. Clone or download this project
2. Open `cactus-test.xcodeproj` in Xcode
3. Build and run the project on your device or simulator

### Model Setup

To use the AI features, you need to add a .gguf model file to the project:

1. **Download a model**: Get a .gguf format model from:
   - [Hugging Face](https://huggingface.co/models?search=gguf)
   - [TheBloke's models](https://huggingface.co/TheBloke)
   - [Cactus model repository](https://github.com/cactus-compute)

2. **Add to project**:
   - Drag the .gguf file into your Xcode project
   - Make sure "Add to target" is checked for your app target
   - The file should appear in the project navigator

3. **Recommended models for testing**:
   - `gemma-2b-it.gguf` (small, fast)
   - `llama-2-7b-chat.gguf` (good balance)
   - `mistral-7b-instruct.gguf` (high quality)

## Usage

### Basic Chat

1. Launch the app
2. Tap the gear icon to select a model
3. Choose your model from the list
4. Wait for the model to load (you'll see a green indicator)
5. Type your message and tap the send button
6. The AI will generate a response locally

### Model Management

- **Load Models**: Tap the gear icon to access model selection
- **Model Info**: View current model status and parameters
- **Switch Models**: Change models without restarting the app

### Advanced Features

- **Stop Generation**: Tap the stop button during generation
- **Context Management**: The app maintains conversation context
- **Offline Operation**: Works completely without internet

## Architecture

### Key Components

- **CactusManager**: Handles all Cactus framework interactions
- **ContentView**: Main chat interface
- **ModelPickerView**: Model selection interface
- **MessageView**: Individual message display

### Cactus Integration

The app uses the Cactus C FFI interface through the bridging header:

```swift
// Initialize Cactus context
var initParams = cactus_init_params_c_t()
initParams.model_path = modelPath
initParams.n_ctx = 2048
// ... other parameters
cactusContext = cactus_init(&initParams)

// Generate responses
var completionParams = cactus_completion_params_c_t()
completionParams.prompt = userMessage
let result = cactus_completion(context, &completionParams)
```

## Configuration

### Model Parameters

You can adjust model parameters in `CactusManager.swift`:

```swift
// Context size
initParams.n_ctx = 2048

// Generation parameters
completionParams.temperature = 0.7
completionParams.top_k = 40
completionParams.top_p = 0.9
```

### Performance Settings

- **CPU Threads**: Adjust `n_threads` for your device
- **Batch Size**: Modify `n_batch` and `n_ubatch` for memory usage
- **GPU Layers**: Set `n_gpu_layers` for GPU acceleration (if available)

## Troubleshooting

### Common Issues

1. **"No model loaded" error**:
   - Ensure you've added a .gguf file to the project
   - Check that the file is included in the app target
   - Verify the model file is valid

2. **Slow generation**:
   - Reduce context size (`n_ctx`)
   - Lower batch sizes
   - Use a smaller model

3. **Memory issues**:
   - Reduce context and batch sizes
   - Close other apps
   - Use a smaller model

### Debug Information

The app provides detailed logging in the Xcode console:
- Model loading progress
- Generation status
- Error messages

## Contributing

This demo app is part of the Cactus ecosystem. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Resources

- [Cactus Framework Documentation](https://github.com/cactus-compute/cactus)
- [Cactus Chat Demo](https://github.com/cactus-compute/demo-cactus-chat)
- [Model Format Guide](https://github.com/ggerganov/ggml)
- [Cactus Community](https://discord.gg/cactus-compute)

## License

This project is licensed under the Apache 2.0 License - see the LICENSE file for details.

---

**Built with ❤️ using the Cactus framework for on-device AI** 