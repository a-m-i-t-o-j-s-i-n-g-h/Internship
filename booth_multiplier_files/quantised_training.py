import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, regularizers # type: ignore # type: ignore
from tensorflow.keras.models import Sequential # type: ignore
from tensorflow.keras.utils import to_categorical # type: ignore
from tensorflow.keras.optimizers import Adam # type: ignore
import matplotlib.pyplot as plt

# ---------- PARAMETERS (All entered at the top of the code) ----------
input_dim = 64
hidden_dim1 = 50
hidden_dim2 = 30
output_dim = 10

# Fixed-point settings for hardware simulation and QAT
# These parameters now define the precision for all fixed-point operations during training
# and for parsing input data.

# N_W, X_W: total bits, integer bits for weights
N_W, X_W = 32, 16 # Q8.8 for weights (1 sign + 7 integer + 8 fractional)

# N_B, X_B: total bits, integer bits for biases
N_B, X_B = 64, 32 # Q16.16 for biases (1 sign + 15 integer + 16 fractional)

# N_A, X_A: total bits, integer bits for activations (layer outputs, fed to next layer)
N_A, X_A = 32, 16 # Q8.8 for activations (1 sign + 7 integer + 8 fractional)

# N_IN_DATA, X_IN_DATA: total bits, integer bits for input data (pixels in train_88.mem)
N_IN_DATA, X_IN_DATA = 32, 16 # Confirmed: 16-bit Q8.8 for inputs

# Training parameters
LEARNING_RATE = 0.001 # REDUCED LEARNING RATE
EPOCHS = 200
BATCH_SIZE = 32
L2_REG_STRENGTH = 0.001

# ---------- FIXED-POINT HELPERS (TensorFlow compatible for Straight-Through Estimator) ----------
@tf.custom_gradient
def quantize_and_saturate_tf_tensor(x, n_total_bits, n_integer_bits):
    """
    Quantizes and saturates a TensorFlow float tensor to a simulated fixed-point float tensor.
    Uses a Straight-Through Estimator (STE) for backpropagation.
    Implements half-rounding before saturation/truncation.

    Args:
        x (tf.Tensor): Input float tensor.
        n_total_bits (int): Total number of bits for the fixed-point representation.
        n_integer_bits (int): Number of integer bits (including sign bit).

    Returns:
        tf.Tensor: Quantized float tensor, representing the fixed-point value.
    """
    n_fractional_bits = n_total_bits - n_integer_bits
    scale = tf.cast(2**n_fractional_bits, tf.float32)

    # Scale the float value to its fixed-point integer representation
    x_scaled = x * scale

    # Implement half-rounding before truncation/saturation.
    # tf.round() typically implements "round to nearest even" for ties,
    # which is a robust rounding method for QAT. This effectively considers
    # the bit after the target fractional bits for rounding decisions.
    x_rounded = tf.round(x_scaled)

    # Calculate min/max representable integer values for saturation
    # For signed 2's complement: max_val = 2^(n-1) - 1, min_val = -2^(n-1)
    max_scaled_int = tf.cast((2**(n_total_bits - 1)) - 1, tf.float32)
    min_scaled_int = tf.cast(-(2**(n_total_bits - 1)), tf.float32)

    # Saturate the rounded integer value
    x_saturated_scaled = tf.clip_by_value(x_rounded, min_scaled_int, max_scaled_int)

    # De-quantize back to float for further TensorFlow operations
    x_quantized = x_saturated_scaled / scale

    # Define the gradient for STE: Identity for forward pass, pass through for backward pass
    def grad(dy):
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
        # The initial input 'X' will be quantized here to N_A, X_A (Q8.8)
        quantized_inputs = quantize_and_saturate_tf_tensor(inputs, N_A, X_A)

        # Quantize weights for the MAC operation to N_W, X_W (Q8.8)
        quantized_kernel = quantize_and_saturate_tf_tensor(self.kernel, N_W, X_W)

        # Quantize biases to N_B, X_B (Q16.16)
        quantized_bias = quantize_and_saturate_tf_tensor(self.bias, N_B, X_B)

        # Perform matrix multiplication with quantized inputs and weights
        # (Internal accumulation is done in full float precision by TensorFlow,
        #  simulating a wide hardware accumulator)
        output = tf.matmul(quantized_inputs, quantized_kernel)

        # Add quantized bias
        output = output + quantized_bias

        # Apply activation function
        output = self.activation_fn(output)

        # Quantize output activations to N_A, X_A (Q8.8) before passing to the next layer.
        # This implements the truncation back to 16-bit (Q8.8) for inter-layer values.
        # Softmax outputs are probabilities (0-1) and are typically not quantized to fixed-point
        # in the same way as internal activations, as it would severely limit their range.
        # The input to softmax is already quantized.
        if not isinstance(self.activation_fn, layers.Softmax):
            output = quantize_and_saturate_tf_tensor(output, N_A, X_A)

        return output

# ---------- LOAD TRAINING DATA ----------
X_train_raw = []
y_train_raw = []

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
print(f"Shape of X after loading: {X.shape}") # Debug print for X shape

# ---------- BUILD & TRAIN MODEL with Quantized Layers ----------
model = Sequential()
model.add(layers.Input(shape=(input_dim,))) # Explicitly define the input shape
model.add(QuantizedDense(hidden_dim1, activation='relu', # Removed input_dim here as Input layer defines it
                             kernel_regularizer=regularizers.L2(L2_REG_STRENGTH), name="quant_dense_1"))
model.add(QuantizedDense(hidden_dim2, activation='relu',
                             kernel_regularizer=regularizers.L2(L2_REG_STRENGTH), name="quant_dense_2"))
model.add(QuantizedDense(output_dim, activation='softmax', name="quant_dense_3"))

# Print model summary to verify layer shapes
model.build(input_shape=(None, input_dim)) # Explicitly build the model with batch dimension (None) and input_dim
model.summary()

model.compile(optimizer=Adam(learning_rate=LEARNING_RATE, clipnorm=1.0), # ADDED clipnorm
              loss='categorical_crossentropy', metrics=['accuracy'])

print("\nStarting Quantization-Aware Training (QAT)...")
history = model.fit(X, y_cat, epochs=EPOCHS, batch_size=BATCH_SIZE, verbose=1)

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
    # The first layer is Input, so we skip it or check for QuantizedDense
    if isinstance(layer, QuantizedDense):
        # Get the current float values of the kernel and bias from the trained model
        # These values reflect the impact of quantization during training due to STE.
        weights_float = layer.kernel.numpy()
        biases_float = layer.bias.numpy()

        weights_to_export_T = weights_float.T # Transpose for export: (out_dim, in_dim)

        # Export weights
        with open(f"layer{layer_idx+1}_weights.mem", "w") as wf:
            for row in weights_to_export_T:
                # Ensure values are not NaN before converting
                if np.isnan(row).any():
                    print(f"Warning: NaN detected in weights for layer {layer_idx+1}. Skipping export for this layer.")
                    break # Skip this row or layer if NaN is present
                bin_row = ''.join([
                    float_to_fixed_bin_str(w, N_W, X_W) for w in row
                ])
                wf.write(bin_row + "\n")

        # Export biases
        with open(f"layer{layer_idx+1}_biases.mem", "w") as bf:
            # Ensure values are not NaN before converting
            if np.isnan(biases_float).any():
                print(f"Warning: NaN detected in biases for layer {layer_idx+1}. Skipping export for this layer.")
            else:
                for b in biases_float:
                    bf.write(float_to_fixed_bin_str(b, N_B, X_B) + "\n")


print("\nQuantized weights and biases export attempted.")
print("Check for 'NaN detected' warnings above if files are missing or incomplete.")