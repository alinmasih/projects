# TFLite Models Directory

Place your TFLite model files here.

## Gait Quality Model

To enable ML-based gait classification, add a `gait_quality.tflite` model file to this directory.

### Model Requirements

- **Input**: 7 features (normalized 0-1)
  1. Head tilt angle (normalized)
  2. Spine angle (normalized)
  3. Left knee angle (normalized)
  4. Right knee angle (normalized)
  5. Hip symmetry (normalized)
  6. Cadence (normalized)
  7. Sway (normalized)

- **Output**: 2 classes
  - [0] Poor Gait probability
  - [1] Good Gait probability

### Model Training

You can train a simple binary classifier using:
- TensorFlow/Keras
- Scikit-learn (with conversion to TFLite)
- Or use pre-trained models from research papers

### Example Model Creation

```python
import tensorflow as tf

# Simple example model
model = tf.keras.Sequential([
    tf.keras.layers.Dense(64, activation='relu', input_shape=(7,)),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(2, activation='softmax')
])

# Compile and train...
# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

# Save
with open('gait_quality.tflite', 'wb') as f:
    f.write(tflite_model)
```

### Note

The app will work without the model - ML classification is optional. Without the model, the app will still provide:
- Real-time pose detection
- Posture analysis
- Gait metrics (steps, cadence, sway)
- Skeleton visualization

