import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, regularizers # type: ignore
from tensorflow.keras.models import Sequential # type: ignore
from tensorflow.keras.utils import to_categorical # type: ignore
from tensorflow.keras.optimizers import Adam # type: ignore
import matplotlib.pyplot as plt

# ---------- PARAMETERS ----------
input_dim = 64
hidden_dim1 = 50
hidden_dim2 = 30
output_dim = 10

# Fixed-point settings for hardware simulation
# These parameters now define the precision for all fixed-point operations during training.
# N_W, X_W: total bits, integer bits for weights
# N_B, X_B: total bits, integer bits for biases
# N_A, X_A: total bits, integer bits for activations (layer outputs)
N_W, X_W = 16, 8   # Q8.8 for weights
N_B, X_B = 32, 16  # Q16.16 for biases (adjust if your hardware bias width is different)
N_A, X_A = 16, 8   # Q8.8 for activations (output of hidden layers)

# ---------- FIXED-POINT HELPERS (TensorFlow compatible for Straight-Through Estimator) ----------
@tf.custom_gradient
def quantize_and_saturate_tf_tensor(x, n_total_bits, n_integer_bits):
    """
    Quantizes and saturates a TensorFlow float tensor to a simulated fixed-point float tensor.
    Uses a Straight-Through Estimator (STE) for backpropagation.

    Args:
        x (tf.Tensor): Input float tensor.
        n_total_bits (int): Total number of bits for the fixed-point representation.
        n_integer_bits (int): Number of integer bits (including sign bit).

    Returns:
        tf.Tensor: Quantized float tensor, representing the fixed-point value.
    """
    n_fractional_bits = n_total_bits - n_integer_bits
    scale = tf.cast(2**n_fractional_bits, tf.float32)

    # Quantize by scaling, rounding to nearest integer, then de-scaling
    x_scaled = x * scale
    x_rounded = tf.round(x_scaled)

    # Calculate min/max representable integer values for saturation
    # max_val_int is for the scaled integer, e.g., for 16-bit signed, max is (2^15 - 1)
    max_scaled_int = tf.cast((2**(n_total_bits - 1)) - 1, tf.float32)
    min_scaled_int = tf.cast(-(2**(n_total_bits - 1)), tf.float32)

    # Saturate the rounded integer value
    x_saturated_scaled = tf.clip_by_value(x_rounded, min_scaled_int, max_scaled_int)

    # De-quantize back to float for further TensorFlow operations
    x_quantized = x_saturated_scaled / scale

    # Define the gradient for STE: Identity for forward pass, pass through for backward pass
    def grad(dy):
        # The gradient of the quantization operation is approximated as 1 (straight-through)
        return dy, None, None # dy for x, None for n_total_bits, None for n_integer_bits
    return x_quantized, grad

# Custom Quantized Dense Layer
class QuantizedDense(layers.Layer):
    def __init__(self, units, activation=None, kernel_regularizer=None, **kwargs):
        super(QuantizedDense, self).__init__(**kwargs)
        self.units = units
        # Use tf.keras.activations.get to handle string names or direct callables
        self.activation_fn = layers.Activation(activation) if activation else tf.identity
        self.kernel_regularizer = regularizers.get(kernel_regularizer)

    def build(self, input_shape):
        self.kernel = self.add_weight(
            name='kernel',
            shape=(input_shape[-1], self.units),
            initializer='glorot_uniform',
            trainable=True,
            regularizer=self.kernel_regularizer
        )
        self.bias = self.add_weight(
            name='bias',
            shape=(self.units,),
            initializer='zeros',
            trainable=True
        )
        super(QuantizedDense, self).build(input_shape)

    def call(self, inputs):
        # Quantize input activations (output from previous layer or initial input)
        # The first layer's input `X` is assumed to be float. It will be quantized here.
        quantized_inputs = quantize_and_saturate_tf_tensor(inputs, N_A, X_A)

        # Quantize weights for the MAC operation
        quantized_kernel = quantize_and_saturate_tf_tensor(self.kernel, N_W, X_W)

        # Quantize biases
        quantized_bias = quantize_and_saturate_tf_tensor(self.bias, N_B, X_B)

        # Perform matrix multiplication with quantized weights
        # This simulates your MAC operation in fixed-point
        output = tf.matmul(quantized_inputs, quantized_kernel)

        # Add quantized bias
        output = output + quantized_bias

        # Apply activation function
        output = self.activation_fn(output)

        # Quantize output activations before passing to the next layer, UNLESS it's a softmax layer
        # Softmax outputs are probabilities (0-1) and are typically not quantized to fixed-point
        # in the same way as internal activations, as it would severely limit their range.
        # The input to softmax should be quantized, but not its output.
        if not isinstance(self.activation_fn, layers.Softmax):
             output = quantize_and_saturate_tf_tensor(output, N_A, X_A)

        return output

# ---------- LOAD TRAINING DATA ----------
X_train_raw = []
y_train_raw = []

# Assuming train_88.mem contains pixel data quantized to a specific format
# Based on your input_88.py, pixel data was described as n_bits=32, int_bits=16 (Q16.16)
# However, your original script used n_w, x_w = 16, 8 (Q8.8) to parse it from the file.
# We'll use the Q16.16 (N_IN, X_IN) from input_88.py for parsing the data correctly.
N_IN_DATA, X_IN_DATA = 16, 8 # Q16.16 as per input_88.py's definition for input pixels

def fixed_bin_to_float_data(bin_str, n, x):
    """Converts a 2's complement binary string to a floating-point value."""
    val_int = int(bin_str, 2)
    # Handle two's complement for negative numbers
    if val_int >= (1 << (n - 1)):
        val_int -= (1 << n)
    return float(val_int) / (2**(n - x))

with open("train_88.mem", "r") as f:
    for line in f:
        line = line.strip()
        pixel_bits = line[:-4] # e.g., 64 pixels * N_IN_DATA bits/pixel
        label_bits = line[-4:]

        image = []
        for i in range(input_dim):
            # Each pixel is N_IN_DATA bits long
            bin_chunk = pixel_bits[i*N_IN_DATA:(i+1)*N_IN_DATA]
            float_val = fixed_bin_to_float_data(bin_chunk, N_IN_DATA, X_IN_DATA)
            image.append(float_val)

        label = int(label_bits, 2)
        X_train_raw.append(image)
        y_train_raw.append(label)

X = np.array(X_train_raw, dtype=np.float32)
y = np.array(y_train_raw, dtype=np.int32)
y_cat = to_categorical(y, num_classes=output_dim)

print(f"Loaded {len(X)} training samples.")

# ---------- BUILD & TRAIN MODEL with Quantized Layers ----------
model = Sequential()
# Replace Dense layers with QuantizedDense to incorporate fixed-point operations
model.add(QuantizedDense(hidden_dim1, input_dim=input_dim, activation='relu',
                         kernel_regularizer=regularizers.L2(0.001), name="quant_dense_1"))
model.add(QuantizedDense(hidden_dim2, activation='relu',
                         kernel_regularizer=regularizers.L2(0.001), name="quant_dense_2"))
# The final layer uses softmax, and its output is typically not quantized to fixed-point
# as it represents probabilities. The inputs to this softmax layer are quantized.
model.add(QuantizedDense(output_dim, activation='softmax', name="quant_dense_3"))


model.compile(optimizer=Adam(learning_rate=0.0006),
              loss='categorical_crossentropy', metrics=['accuracy'])

print("\nStarting Quantization-Aware Training (QAT)...")
history = model.fit(X, y_cat, epochs=200, batch_size=16, verbose=1)

# ---------- PLOT LOSS ----------
plt.figure(figsize=(8, 5))
plt.plot(history.history['loss'], label='Training Loss', color='red', linewidth=2)
plt.xlabel('Epoch')
plt.ylabel('Loss')
plt.title('Training Loss Curve (Quantization-Aware)')
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.show()

# ---------- EXPORT QUANTIZED WEIGHTS & BIASES ----------
# These are the functions to convert float values (which were trained with QAT)
# to their final fixed-point binary string representation for hardware.
def float_to_fixed_bin_str(val, n_total, n_integer):
    n_fractional = n_total - n_integer
    scaled_val = round(val * (2**n_fractional))

    # Clamp to the actual representable integer range
    max_representable_int = (2**(n_total - 1)) - 1
    min_representable_int = -(2**(n_total - 1))
    clamped_val = int(max(min(scaled_val, max_representable_int), min_representable_int))

    # Convert to two's complement binary string
    if clamped_val < 0:
        clamped_val = (1 << n_total) + clamped_val
    return format(clamped_val, f'0{n_total}b')


for layer_idx, layer in enumerate(model.layers):
    if isinstance(layer, QuantizedDense): # Only process our custom quantized layers
        # Get the current float values of the kernel and bias from the trained model
        # These values reflect the impact of quantization during training due to STE.
        weights_float = layer.kernel.numpy()
        biases_float = layer.bias.numpy()

        weights_to_export_T = weights_float.T # Transpose for export: (out_dim, in_dim)

        # Export weights
        with open(f"layer{layer_idx+1}_weights.mem", "w") as wf:
            for row in weights_to_export_T:
                bin_row = ''.join([
                    float_to_fixed_bin_str(w, N_W, X_W) for w in row
                ])
                wf.write(bin_row + "\n")

        # Export biases
        with open(f"layer{layer_idx+1}_biases.mem", "w") as bf:
            for b in biases_float:
                bf.write(float_to_fixed_bin_str(b, N_B, X_B) + "\n")

print("\nQuantized weights and biases exported to .mem files.")