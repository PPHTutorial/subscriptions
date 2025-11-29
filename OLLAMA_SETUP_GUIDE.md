# Ollama Integration Guide for Subscription Insights

## Overview

The `dart-ollama` package provides a clean API to connect to Ollama servers for generating natural language insights about subscriptions. Ollama can run locally on your machine or on a remote server.

## How It Works

```
Flutter App (Mobile/Desktop)
    ↓ dart-ollama package API
Ollama Server (Local or Remote)
    ↓ LLM Processing
Natural Language Insights
    ↓ Stream Response
Flutter App (Enhanced Insights)
```

## Important Notes

✅ **The dart-ollama package simplifies connection**
- No need to manually handle HTTP requests
- Clean API with `Ollama()` and `chat()` methods
- Handles streaming responses automatically
- Can connect to local or remote Ollama servers

⚠️ **Ollama server must still be running somewhere**
- Option 1: Local machine (localhost:11434)
- Option 2: Remote server (your server URL)
- Option 3: Cloud-hosted Ollama instance

## Setup Instructions

### Step 1: Install Ollama

**Windows/Mac/Linux:**
```bash
# Download from https://ollama.ai
# Or use package manager:
# macOS: brew install ollama
# Linux: curl -fsSL https://ollama.ai/install.sh | sh
```

### Step 2: Pull a Model

Choose a small, fast model for mobile use:

```bash
# Recommended small models (fast, low memory):
ollama pull llama3.2        # ~2GB - Best balance
ollama pull phi3            # ~2.2GB - Fast
ollama pull qwen2.5:0.5b    # ~500MB - Smallest
ollama pull mistral:7b      # ~4GB - Better quality

# For testing (very small):
ollama pull tinyllama       # ~600MB - Fastest
```

### Step 3: Start Ollama Server

```bash
ollama serve
```

The server runs on `http://localhost:11434` by default.

### Step 4: Configure Your Flutter App

The app uses the `dart-ollama` package which simplifies the connection:

```dart
// Simple usage - connects to localhost:11434 by default
final ollama = Ollama();

// Or specify a custom server URL
final ollama = Ollama(baseUrl: Uri.parse('http://your-server:11434'));
```

The app is already configured! It will:
1. Try to connect to `http://localhost:11434` (or your specified URL)
2. Use `llama3.2` model by default
3. Fall back to rule-based insights if Ollama is unavailable

### Step 5: For Mobile Testing

Since Ollama runs on your computer, for mobile testing you need:

**Option A: Use Same Network**
1. Find your computer's local IP (e.g., `192.168.1.100`)
2. Update Ollama URL in code:
   ```dart
   OllamaInsightsService(
     ollamaUrl: 'http://192.168.1.100:11434',
   )
   ```

**Option B: Use ngrok (for testing)**
```bash
ngrok http 11434
# Use the ngrok URL in your app
```

**Option C: Deploy Ollama to a Server**
- Deploy Ollama to a cloud server
- Use the server URL in your app

## How It Enhances Insights

### Before (Rule-Based):
```
"You have 3 subscription(s) that may be inactive. 
This could save you $45.00 per month."
```

### After (Ollama-Enhanced):
```
"Based on your subscription patterns, I noticed 3 services 
haven't been renewed in over 90 days. Canceling Netflix, 
Spotify, and Adobe could free up $45 monthly - that's $540 
a year you could redirect to savings or other priorities!"
```

## Features

### 1. Natural Language Generation
- Converts rule-based insights into conversational messages
- Personalizes recommendations
- Adds context and empathy

### 2. Additional Insights
- Discovers patterns rule-based logic might miss
- Provides creative suggestions
- Identifies hidden opportunities

### 3. Hybrid Approach
- Rule-based logic for calculations (fast, reliable)
- Ollama for natural language (enhanced UX)
- Automatic fallback if Ollama unavailable

## Configuration

### Basic Usage

```dart
final insightsService = AiInsightsService();

// Automatically tries Ollama, falls back to rule-based
final insights = await insightsService.generateAiInsights(subscriptions);
```

### Custom Configuration

```dart
final ollamaService = OllamaInsightsService(
  ollamaUrl: 'http://your-server:11434',
  modelName: 'phi3',  // or 'llama3.2', 'qwen2.5:0.5b', etc.
  useOllama: true,
);

final insights = await ollamaService.generateInsights(subscriptions);
```

## Model Recommendations

| Model | Size | Speed | Quality | Best For |
|-------|------|-------|---------|----------|
| **llama3.2** | ~2GB | Fast | Good | ⭐ Recommended |
| **phi3** | ~2.2GB | Very Fast | Good | Quick responses |
| **qwen2.5:0.5b** | ~500MB | Fastest | Basic | Mobile testing |
| **mistral:7b** | ~4GB | Medium | Excellent | Better quality |
| **tinyllama** | ~600MB | Fastest | Basic | Development |

## API Endpoints Used

The service uses Ollama's REST API:

1. **Check Availability**: `GET /api/tags`
2. **Generate Text**: `POST /api/generate`

## Privacy & Security

✅ **Benefits**:
- Data stays on your machine/server
- No external API calls
- No data collection
- GDPR/privacy compliant
- Works offline (once server is running)

## Troubleshooting

### "Ollama not available"
- Ensure Ollama server is running: `ollama serve`
- Check if model is pulled: `ollama list`
- Verify URL is correct

### "Connection timeout"
- Check firewall settings
- Ensure mobile device and server are on same network
- Verify Ollama server is accessible

### "Model not found"
- Pull the model: `ollama pull llama3.2`
- Check model name matches in code

### Slow Responses
- Use smaller models (qwen2.5:0.5b, tinyllama)
- Reduce `max_tokens` in prompts
- Consider using rule-based insights for speed

## Production Considerations

### For Production Apps:

1. **Option 1: Self-Hosted Server**
   - Deploy Ollama to your own server
   - Use secure connection (HTTPS)
   - Add authentication if needed

2. **Option 2: Hybrid Approach**
   - Use rule-based insights by default (fast, reliable)
   - Offer Ollama as optional "premium" feature
   - Let users connect their own Ollama server

3. **Option 3: Cloud Deployment**
   - Deploy Ollama to cloud (AWS, GCP, Azure)
   - Use API gateway for security
   - Scale as needed

## Example Integration

The service is already integrated! Just ensure:

1. Ollama is installed and running
2. A model is pulled (e.g., `ollama pull llama3.2`)
3. Server is accessible from your app

The app will automatically:
- Try to use Ollama for enhanced insights
- Fall back to rule-based if unavailable
- Provide natural language insights when possible

## Next Steps

1. Install Ollama on your development machine
2. Pull a model: `ollama pull llama3.2`
3. Start server: `ollama serve`
4. Test the insights feature in your app
5. Enjoy AI-powered subscription insights! 🚀

