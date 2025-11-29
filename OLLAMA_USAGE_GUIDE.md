# Using Ollama with dart-ollama Package

## Key Point

The `dart-ollama` package **simplifies the API** - you don't need to write HTTP code manually, but you **still need an Ollama server running somewhere**.

## How dart-ollama Works

Based on the [example](https://raw.githubusercontent.com/breitburg/dart-ollama/main/example/ollama_example.dart):

```dart
import 'package:ollama/ollama.dart';

// Simple - no manual HTTP handling!
final ollama = Ollama(); // Connects to localhost:11434 by default

// Or connect to remote server
final ollama = Ollama(baseUrl: Uri.parse('http://your-server:11434'));

// Use clean chat API
final response = ollama.chat([
  ChatMessage(role: 'system', content: 'You are a helpful assistant.'),
  ChatMessage(role: 'user', content: 'How are you?'),
], model: 'llama3');

// Response is a stream - collect it
response.listen((chunk) {
  print(chunk.message?.content);
});
```

## Server Options

### Option 1: Local Server (Development)
```bash
# Install Ollama on your PC
# Download from https://ollama.ai

# Start server
ollama serve

# Pull a model
ollama pull llama3.2
```

Then in your app:
```dart
final ollama = Ollama(); // Uses localhost:11434
```

### Option 2: Remote Server (Production)
Deploy Ollama to a cloud server (AWS, GCP, Azure, etc.)

Then in your app:
```dart
final ollama = Ollama(
  baseUrl: Uri.parse('https://your-ollama-server.com'),
);
```

### Option 3: Same Network (Mobile Testing)
If testing mobile app on same network as your PC:

```dart
// Find your PC's local IP (e.g., 192.168.1.100)
final ollama = Ollama(
  baseUrl: Uri.parse('http://192.168.1.100:11434'),
);
```

## What the Package Does

✅ **Simplifies**:
- No manual HTTP requests
- No JSON encoding/decoding
- Clean `chat()` API
- Automatic streaming handling
- Type-safe ChatMessage objects

❌ **Still Requires**:
- Ollama server running somewhere
- Model downloaded on that server
- Network connectivity to server

## Benefits Over Raw HTTP

**Before (Raw HTTP)**:
```dart
final response = await http.post(
  Uri.parse('http://localhost:11434/api/generate'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'model': 'llama3.2',
    'prompt': prompt,
    'stream': false,
  }),
);
final data = jsonDecode(response.body);
```

**After (dart-ollama package)**:
```dart
final response = ollama.chat([
  ChatMessage(role: 'user', content: prompt),
], model: 'llama3.2');
```

Much cleaner! 🎉

## Current Implementation

The `OllamaInsightsService` now uses the dart-ollama package:
- Clean API with `Ollama()` and `chat()` methods
- Automatic connection handling
- Stream processing for responses
- Easy to switch between local/remote servers

## Summary

- ✅ **dart-ollama package**: Simplifies API, no manual HTTP
- ✅ **Can connect to**: Local, remote, or cloud Ollama servers
- ⚠️ **Still needs**: Ollama server running somewhere
- 🎯 **Best for**: Clean code, easy server switching, production-ready

