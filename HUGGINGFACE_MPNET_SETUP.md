# Hugging Face MPNet/DistilBERT Setup Guide

This guide explains how to use Microsoft MPNet or DistilBERT for subscription insights via Hugging Face Inference API - **no server setup required!**

## Why Hugging Face Inference API?

✅ **No server setup** - Uses Hugging Face's hosted models  
✅ **Free tier available** - 1,000 requests/month free  
✅ **Easy to use** - Just provide an API key (optional for public models)  
✅ **Production ready** - Reliable, scalable infrastructure  
✅ **Multiple models** - MPNet, DistilBERT, and more

## Models Supported

### Microsoft MPNet (Recommended)
- **Model**: `sentence-transformers/all-mpnet-base-v2`
- **Best for**: Semantic similarity, finding similar subscriptions
- **Pros**: Most accurate for similarity tasks
- **Use case**: Detect duplicate/overlapping subscriptions

### DistilBERT
- **Model**: `distilbert-base-uncased`
- **Best for**: Text classification, category detection
- **Pros**: Faster, lighter than BERT
- **Use case**: Classify subscription categories

## Setup Steps

### 1. Get Hugging Face API Key (Optional)

1. Go to https://huggingface.co/settings/tokens
2. Create a new token (read access is enough)
3. Copy the token

**Note**: API key is optional - public models work without authentication, but you'll have rate limits.

### 2. Update Flutter App

The service is already integrated! Just enable it:

```dart
final insights = await insightsService.generateAiInsights(
  subscriptions,
  enableNer: true,
  nerServerUrl: 'your-huggingface-api-key', // Optional
);
```

### 3. How It Works

The service uses Hugging Face Inference API to:

1. **Generate embeddings** using MPNet for each subscription
2. **Calculate similarity** between subscriptions using cosine similarity
3. **Classify categories** using zero-shot classification (BART model)
4. **Generate insights** about duplicates, spending, etc.

## Features

### 1. Similar Subscription Detection
- Uses MPNet embeddings to find semantically similar subscriptions
- Detects duplicates and overlaps (e.g., "Netflix" and "Netflix Premium")
- Cosine similarity threshold: 0.7

### 2. Category Classification
- Uses zero-shot classification (BART model)
- Automatically classifies subscriptions into categories
- Works with service names and descriptions

### 3. Spending Analysis
- Calculates total monthly spending
- Identifies high-spending patterns
- Suggests optimization opportunities

## API Usage

### Free Tier Limits
- **1,000 requests/month** (with API key)
- **30 requests/hour** (without API key)
- **Rate limiting** may apply during peak times

### Paid Plans
- **Pro**: $9/month - 10,000 requests/month
- **Enterprise**: Custom pricing for higher limits

## Example Usage

```dart
// Without API key (public models, rate limited)
final nerService = NerInsightsService(
  useNer: true,
);

// With API key (recommended for production)
final nerService = NerInsightsService(
  apiKey: 'hf_your_api_key_here',
  modelName: 'sentence-transformers/all-mpnet-base-v2', // or 'distilbert-base-uncased'
  useNer: true,
);

// Check availability
if (await nerService.isNerAvailable()) {
  final insights = await nerService.generateInsights(subscriptions);
}

// Classify category
final category = await nerService.classifyCategory(
  'Netflix streaming subscription monthly',
  'Netflix',
);
```

## Error Handling

The service automatically:
- ✅ Falls back to rule-based insights if API is unavailable
- ✅ Handles rate limits gracefully
- ✅ Retries on model loading (503 status)
- ✅ Works offline with rule-based insights

## Cost Considerations

### Free Tier
- Perfect for development and testing
- 1,000 requests/month is enough for personal use
- No credit card required

### Production
- Consider paid plan for production apps
- Or implement caching to reduce API calls
- Or use rule-based insights as primary, AI as enhancement

## Alternatives

If you need more control or higher limits:

1. **Self-hosted models** - Deploy models on your own infrastructure
2. **TensorFlow Lite** - On-device inference (no API calls)
3. **ONNX Runtime** - On-device inference with ONNX models

## Troubleshooting

### "Model is loading" (503 error)
- **Solution**: The service automatically retries after 2 seconds
- **Cause**: Hugging Face loads models on-demand for free tier

### Rate limit exceeded
- **Solution**: Add API key for higher limits
- **Alternative**: Use rule-based insights as fallback

### Network errors
- **Solution**: Service automatically falls back to rule-based insights
- **Check**: Internet connection and Hugging Face API status

## Security

- ✅ API keys are optional (public models work without)
- ✅ HTTPS encryption for all API calls
- ✅ No data stored by Hugging Face (stateless API)
- ✅ API keys can be revoked anytime

## Next Steps

1. **Get API key** (optional but recommended)
2. **Enable NER** in your app settings
3. **Test with your subscriptions**
4. **Monitor API usage** in Hugging Face dashboard

That's it! No server setup, no deployment, just works! 🚀

