# Local AI Models for Flutter Subscription Insights

## Recommended Solutions

### 1. **TensorFlow Lite (tflite_flutter)** ⭐ Best for Custom Models
**Package**: `tflite_flutter: ^0.10.0`

**Use Cases**:
- Subscription categorization
- Spending pattern prediction
- Waste detection models
- Custom classification tasks

**Pros**:
- ✅ Mature and well-documented
- ✅ Excellent performance on mobile
- ✅ Supports quantization (smaller models)
- ✅ Works offline
- ✅ Good Flutter support

**Cons**:
- ❌ Requires model training/conversion
- ❌ Need to create or find pre-trained models

**Implementation**:
```yaml
dependencies:
  tflite_flutter: ^0.10.0
```

**Example Use**:
```dart
import 'package:tflite_flutter/tflite_flutter.dart';

class SubscriptionClassifier {
  late Interpreter interpreter;
  
  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset('subscription_classifier.tflite');
  }
  
  String classifySubscription(Subscription sub) {
    var input = _prepareInput(sub);
    var output = List.filled(5, 0.0).reshape([1, 5]);
    interpreter.run(input, output);
    return _interpretOutput(output);
  }
}
```

---

### 2. **ONNX Runtime** ⭐ Best for Pre-trained Models
**Package**: `onnxruntime: ^1.15.0` or `dart_onnxruntime`

**Use Cases**:
- Running pre-trained models from Hugging Face
- Cross-platform model deployment
- Using models trained in PyTorch/TensorFlow

**Pros**:
- ✅ Cross-platform (iOS, Android, Web)
- ✅ Good performance
- ✅ Large model ecosystem
- ✅ Supports quantization

**Cons**:
- ❌ Setup can be complex
- ❌ Larger package size

**Implementation**:
```yaml
dependencies:
  onnxruntime: ^1.15.0
```

---

### 3. **llama.cpp Bindings** ⭐ Best for Natural Language Insights
**Packages**: 
- `llama_cpp_dart: ^0.1.0` (if available)
- Or use platform channels with llama.cpp

**Use Cases**:
- Generating natural language insights
- Text summarization
- Sentiment analysis
- Conversational AI features

**Recommended Models** (Small, quantized):
- **TinyLlama** (~600MB quantized)
- **Phi-2** (~1.6GB quantized)
- **Qwen2.5-0.5B** (~500MB quantized)
- **Gemma-2B** (~1.3GB quantized)

**Pros**:
- ✅ Natural language generation
- ✅ Can generate human-like insights
- ✅ No API costs
- ✅ Privacy-preserving

**Cons**:
- ❌ Large model files
- ❌ Requires significant memory
- ❌ Slower inference on older devices
- ❌ Complex setup

**Implementation** (via platform channels):
```dart
// Use MethodChannel to call native llama.cpp
final result = await platform.invokeMethod('generateInsight', {
  'subscriptions': subscriptionsJson,
  'modelPath': 'assets/models/tinyllama.q4_0.gguf',
});
```

---

### 4. **Google ML Kit** (Already Using)
**Package**: `google_mlkit_text_recognition` ✅ Already installed

**Use Cases**:
- Text recognition (already using)
- Could extend with other ML Kit features

**Available Features**:
- Text Recognition ✅ (using)
- Language Identification
- Smart Reply (for suggestions)
- Entity Extraction

**Limitations**:
- ❌ No text generation
- ❌ Limited to pre-built features
- ❌ Not suitable for custom insights

---

## Recommended Approach for Subscription Insights

### **Hybrid Solution** (Best Balance)

1. **TensorFlow Lite** for:
   - Subscription categorization
   - Spending pattern analysis
   - Waste prediction models

2. **Rule-based logic** (current approach) for:
   - Basic insights
   - Budget calculations
   - Overlap detection

3. **Optional: Small LLM** (if needed) for:
   - Natural language insight generation
   - Personalized recommendations

---

## Implementation Plan

### Phase 1: TensorFlow Lite Integration
1. Add `tflite_flutter` package
2. Create/obtain a subscription classification model
3. Train model on subscription data patterns
4. Convert to TFLite format
5. Integrate into `AiInsightsService`

### Phase 2: Enhanced Insights
1. Use TFLite for pattern recognition
2. Combine with rule-based logic
3. Generate more accurate insights

### Phase 3: Optional LLM Integration
1. If natural language is needed, integrate llama.cpp
2. Use quantized small models (TinyLlama/Phi-2)
3. Generate human-like insight descriptions

---

## Model Training Resources

### For TensorFlow Lite:
- **TensorFlow Lite Model Maker**: https://www.tensorflow.org/lite/models/modify/model_maker
- **Hugging Face**: Pre-trained models that can be converted
- **TensorFlow Hub**: Pre-trained models

### For ONNX:
- **Hugging Face ONNX Models**: https://huggingface.co/models?library=onnx
- **ONNX Model Zoo**: https://github.com/onnx/models

### For LLMs:
- **Hugging Face**: https://huggingface.co/models
- **llama.cpp**: https://github.com/ggerganov/llama.cpp
- **GGUF Models**: Quantized models ready for mobile

---

## Quick Start: TensorFlow Lite

```yaml
# pubspec.yaml
dependencies:
  tflite_flutter: ^0.10.0
```

```dart
// Example: Load and use a model
import 'package:tflite_flutter/tflite_flutter.dart';

class LocalAiService {
  Interpreter? _interpreter;
  
  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset('insights_model.tflite');
  }
  
  Future<String> generateInsight(List<Subscription> subs) async {
    // Prepare input from subscriptions
    final input = _prepareSubscriptionData(subs);
    
    // Run inference
    final output = List.filled(1, 0.0).reshape([1, 1]);
    _interpreter?.run(input, output);
    
    // Interpret results
    return _formatInsight(output[0][0]);
  }
}
```

---

## Performance Considerations

1. **Model Size**: Keep models under 50MB for mobile
2. **Quantization**: Use INT8 quantized models (4x smaller)
3. **Lazy Loading**: Load models only when needed
4. **Caching**: Cache inference results
5. **Background Processing**: Run AI in background isolates

---

## Privacy & Security

✅ **All local AI models**:
- Data never leaves device
- No API costs
- Works offline
- GDPR/privacy compliant
- No data collection

---

## Recommended Next Steps

1. **Start with TensorFlow Lite** for custom classification
2. **Enhance current rule-based logic** with ML predictions
3. **Consider LLM only if** natural language generation is critical
4. **Test on real devices** to ensure performance

---

## Resources

- TensorFlow Lite: https://www.tensorflow.org/lite
- ONNX Runtime: https://onnxruntime.ai
- llama.cpp: https://github.com/ggerganov/llama.cpp
- Flutter AI Packages: https://pub.dev/packages?q=ai+ml

