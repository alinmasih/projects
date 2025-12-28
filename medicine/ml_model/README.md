# TensorFlow Lite Medicine Embedder Model

This directory contains the pre-trained ML model for medicine verification.

## Model Details

- **Name**: medicine_embedder.tflite
- **Type**: Image embedding model (extracts 128D vectors)
- **Input**: 224x224 RGB images
- **Output**: 128-dimensional embedding vector
- **Framework**: TensorFlow Lite (optimized for mobile)

## Setup

1. **Download a pre-trained model**:
   - Option A: MobileNetV2 from TensorFlow Hub
   - Option B: EfficientNet-Lite
   - Option C: Train custom model on medicine images

2. **Convert to TFLite**:
   ```python
   import tensorflow as tf
   
   # Load your trained model
   model = tf.keras.models.load_model('your_model.h5')
   
   # Convert to TFLite
   converter = tf.lite.TFLiteConverter.from_keras_model(model)
   tflite_model = converter.convert()
   
   # Save
   with open('medicine_embedder.tflite', 'wb') as f:
       f.write(tflite_model)
   ```

3. **Place in this directory**:
   ```bash
   cp path/to/medicine_embedder.tflite ./
   ```

## Usage in Flutter

```dart
// lib/services/ml_service.dart

// Load model
await mlService.loadModel();

// Extract embedding from image
final embedding = await mlService.extractEmbedding(imageFile);

// Compare embeddings
final result = await mlService.verifyMedicine(
  capturedImageFile: capturedImage,
  medicinesInSlot: medicines,
);
```

## Model Customization

### Input/Output Sizes
Edit `lib/services/ml_service.dart`:
```dart
static const int _INPUT_SIZE = 224;      // Your model's input size
static const int _EMBEDDING_SIZE = 128;  // Your model's output size
static const double _SIMILARITY_THRESHOLD = 0.75;  // Confidence threshold
```

### Similarity Threshold
- Increase (e.g., 0.85) for stricter matching
- Decrease (e.g., 0.70) for more lenient matching

## Training Custom Model

See `scripts/train_embedder.py` for an example of training a custom medicine embedder using:
- Transfer learning from pre-trained ImageNet weights
- Metric learning (Triplet loss or ArcFace)
- Medicine image dataset

## TensorFlow Hub Models

Recommended models for mobile:
- https://tfhub.dev/google/lite-model/mobilenet_v2/1
- https://tfhub.dev/google/lite-model/efficientnet/lite0/1
- https://tfhub.dev/google/lite-model/efficientnet/lite1/1

## Performance

On Pixel 4 (Snapdragon 765):
- Embedding extraction: ~50-100ms
- Cosine similarity: <1ms
- Total verification: ~150-200ms

## Notes

- Model must output embeddings (intermediate layer activation)
- Not the classification layer (which has medicine class names)
- Embeddings must be normalized (L2 norm)
- Ensure input preprocessing matches training (normalization, resizing)

