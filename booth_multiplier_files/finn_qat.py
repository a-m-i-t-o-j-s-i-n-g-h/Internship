# finn_qat_fixed.py
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, regularizers
from tensorflow.keras.models import Sequential
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.optimizers import Adam
import matplotlib.pyplot as plt
from pathlib import Path
import sys

# ---------------- CONFIG ----------------
input_dim = 64
hidden_dim1 = 50
hidden_dim2 = 30
output_dim = 10

# FINN quantization precisions (bits)
FINN_BITS_ACT_WEIGHT = 8   # FINN n for activations & weights (your request)
FINN_BITS_BIAS = 16       # FINN n for biases

# Export Q-formats for hardware (final conversion)
EXPORT_N_W, EXPORT_X_W = 16, 8   # Q8.8 for weights/activations/inputs
EXPORT_N_B, EXPORT_X_B = 32, 16  # Q16.16 for biases

# Input binary format in train_88.mem (assumed)
N_IN_DATA = 16   # bits per pixel in file
X_IN_DATA = 8    # integer bits in stored pixel Q-format (Q8.8)
LABEL_BITS = 4
TRAIN_MEM_PATH = "train_88.mem"

# Training params
LEARNING_RATE = 3e-4
EPOCHS = 60
BATCH_SIZE = 32
L2_REG = 1e-3
VALIDATION_SPLIT = 0.15
SEED = 42
tf.random.set_seed(SEED)
np.random.seed(SEED)

# ---------------- FINN QUANTIZER (TensorFlow + STE) ----------------
@tf.custom_gradient
def quantize_finn_tf(x, n_bits):
    """
    FINN-style quantizer with Straight-Through Estimator (STE).
    n_bits: should be a Python int (e.g., 8 or 16). Range step = 1/2^(n_bits-2),
           and quantization interval is [-2+step, 2-step].
    Returns a float tensor containing quantized values. Gradient is STE.
    """
    # If someone accidentally passes a tensor for n_bits, try to get its static value
    if not isinstance(n_bits, int):
        try:
            val = tf.get_static_value(n_bits)
            if val is None:
                val = int(tf.keras.backend.get_value(n_bits))
            n_bits = int(val)
        except Exception:
            # fallback: coerce to int (shouldn't normally happen)
            n_bits = int(n_bits)

    # compute step and bounds (as Python floats) then convert to TF constants
    step_val = 1.0 / (2 ** (n_bits - 2))
    min_val = -2.0 + step_val
    max_val = 2.0 - step_val

    step = tf.constant(step_val, dtype=tf.float32)
    min_tf = tf.constant(min_val, dtype=tf.float32)
    max_tf = tf.constant(max_val, dtype=tf.float32)

    x = tf.cast(x, tf.float32)
    x_clipped = tf.clip_by_value(x, min_tf, max_tf)
    q_int = tf.round((x_clipped - min_tf) / step)  # integer index (in float dtype)
    x_quant = q_int * step + min_tf

    def grad(dy):
        # Straight-through: propagate gradient unchanged to inputs
        return tf.cast(dy, tf.float32), None

    return x_quant, grad

# small wrapper to ensure correct dtype used
def q_finn(x, n_bits):
    return quantize_finn_tf(tf.convert_to_tensor(x, dtype=tf.float32), int(n_bits))

# ---------------- FinnQuantDense layer ----------------
class FinnQuantDense(layers.Layer):
    def __init__(self, units, activation=None, kernel_regularizer=None, name=None):
        super(FinnQuantDense, self).__init__(name=name)
        self.units = int(units)
        self.activation_name = activation if isinstance(activation, str) else None
        self.activation = tf.keras.activations.get(activation)
        self.kernel_regularizer = regularizers.get(kernel_regularizer)

    def build(self, input_shape):
        in_dim = int(input_shape[-1])
        self.kernel = self.add_weight(
            name='kernel',
            shape=(in_dim, self.units),
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
        super(FinnQuantDense, self).build(input_shape)

    def call(self, inputs, training=False):
        # Quantize inputs and kernel according to FINN scheme (STE)
        q_inputs = quantize_finn_tf(inputs, FINN_BITS_ACT_WEIGHT)
        q_kernel = quantize_finn_tf(self.kernel, FINN_BITS_ACT_WEIGHT)
        q_bias = quantize_finn_tf(self.bias, FINN_BITS_BIAS)

        out = tf.matmul(q_inputs, q_kernel) + q_bias

        out = self.activation(out)

        # If not softmax, quantize activation output (preparing for next layer)
        # For softmax final layer, it's okay to keep as float probabilities (no FINN quantize)
        if self.activation_name != 'softmax':
            out = quantize_finn_tf(out, FINN_BITS_ACT_WEIGHT)

        return out

    def compute_output_shape(self, input_shape):
        return (input_shape[0], self.units)

    def get_config(self):
        base = super(FinnQuantDense, self).get_config()
        base.update({
            "units": self.units,
            "activation": self.activation_name,
            "kernel_regularizer": self.kernel_regularizer,
        })
        return base

# ---------------- Data loader ----------------
def fixed_bin_to_float(bin_str, total_bits, integer_bits):
    """Convert two's complement binary string -> float using Q-format."""
    iv = int(bin_str, 2)
    if iv >= (1 << (total_bits - 1)):
        iv -= (1 << total_bits)
    frac_bits = total_bits - integer_bits
    return float(iv) / (2 ** frac_bits)

if not Path(TRAIN_MEM_PATH).exists():
    print(f"ERROR: {TRAIN_MEM_PATH} not found. Place it in current folder.", file=sys.stderr)
    sys.exit(1)

X_list = []
y_list = []
expected_len = input_dim * N_IN_DATA + LABEL_BITS
with open(TRAIN_MEM_PATH, "r") as f:
    for i, line in enumerate(f):
        s = line.strip()
        if len(s) < expected_len:
            raise ValueError(f"Line {i} length {len(s)} < expected {expected_len}")

        pixel_bits = s[: input_dim * N_IN_DATA]
        label_bits = s[input_dim * N_IN_DATA : input_dim * N_IN_DATA + LABEL_BITS]

        img = []
        for j in range(input_dim):
            chunk = pixel_bits[j*N_IN_DATA : (j+1)*N_IN_DATA]
            fval = fixed_bin_to_float(chunk, N_IN_DATA, X_IN_DATA)
            img.append(fval)
        lbl = int(label_bits, 2)
        X_list.append(img)
        y_list.append(lbl)

X = np.array(X_list, dtype=np.float32)
y = np.array(y_list, dtype=np.int32)
print("Loaded data shape:", X.shape, "labels shape:", y.shape)
print("Label distribution:", np.unique(y, return_counts=True))
y_cat = to_categorical(y, num_classes=output_dim)

# Optional: normalize inputs to [-1,1] or [-2,2] if needed
# If raw values are already Q8.8 with reasonable range, you may skip normalization.
# Example normalization to [-1,1]:
# X = X / np.max(np.abs(X))

# ---------------- Build model ----------------
tf.keras.backend.clear_session()
model = Sequential([
    layers.Input(shape=(input_dim,)),
    FinnQuantDense(hidden_dim1, activation='relu', kernel_regularizer=regularizers.l2(L2_REG), name='finn_q_1'),
    FinnQuantDense(hidden_dim2, activation='relu', kernel_regularizer=regularizers.l2(L2_REG), name='finn_q_2'),
    FinnQuantDense(output_dim, activation='softmax', name='finn_q_out')
])
model.build(input_shape=(None, input_dim))
model.summary()

# ---------------- Train ----------------
model.compile(
    optimizer=Adam(learning_rate=LEARNING_RATE),
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

history = model.fit(
    X, y_cat,
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    validation_split=VALIDATION_SPLIT,
    shuffle=True,
    verbose=2
)

# ---------------- Plot loss / acc ----------------
plt.figure(figsize=(10,4))
plt.subplot(1,2,1)
plt.plot(history.history['loss'], label='train loss')
plt.plot(history.history.get('val_loss', []), label='val loss')
plt.title('Loss'); plt.legend(); plt.grid(True)
plt.subplot(1,2,2)
plt.plot(history.history['accuracy'], label='train acc')
plt.plot(history.history.get('val_accuracy', []), label='val acc')
plt.title('Accuracy'); plt.legend(); plt.grid(True)
plt.tight_layout()
plt.show()

# ---------------- Export quantized weights & biases to Q-formats ----------------
def float_to_fixed_bin_str(val, total_bits, integer_bits):
    frac = total_bits - integer_bits
    scaled = int(np.round(val * (2 ** frac)))
    max_int = (2 ** (total_bits - 1)) - 1
    min_int = -(2 ** (total_bits - 1))
    clamped = int(max(min(scaled, max_int), min_int))
    if clamped < 0:
        clamped = (1 << total_bits) + clamped
    return format(clamped, f'0{total_bits}b')

layer_idx = 0
for layer in model.layers:
    if isinstance(layer, FinnQuantDense):
        W = layer.kernel.numpy()   # shape (in_dim, out_dim)
        b = layer.bias.numpy()     # shape (out_dim,)
        W_export = W.T             # (out_dim, in_dim)

        wfname = f"layer{layer_idx+1}_weights.mem"
        bfname = f"layer{layer_idx+1}_biases.mem"
        with open(wfname, "w") as wf:
            for row in W_export:
                row_bits = ''.join([float_to_fixed_bin_str(float(w), EXPORT_N_W, EXPORT_X_W) for w in row])
                wf.write(row_bits + "\n")
        with open(bfname, "w") as bf:
            for bv in b:
                bf.write(float_to_fixed_bin_str(float(bv), EXPORT_N_B, EXPORT_X_B) + "\n")
        print(f"Exported layer {layer_idx+1} -> {wfname}, {bfname}")
        layer_idx += 1

print("Export complete.")
