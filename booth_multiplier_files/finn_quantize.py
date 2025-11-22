import numpy as np
from tensorflow.keras import layers, regularizers
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.optimizers import Adam
import matplotlib.pyplot as plt
import sys
from pathlib import Path

# ---------- PARAMETERS ----------
input_dim = 64
hidden_dim1 = 50
hidden_dim2 = 30
output_dim = 10

# Fixed point formats (Q8.8)
# n = total bits, x = integer bits (including sign bit)
n_in, x_in = 16, 8   # input format Q8.8
n_w, x_w = 16, 8   # weight format Q8.8
n_b, x_b = 32, 16     # bias format Q8.8 (kept same as weights)
TRAIN_MEM_PATH = "train_88.mem"

# Label bit width in the file (adjust if labels use different number of bits)
LABEL_BITS = 4

# ---------- FIXED-POINT HELPERS ----------
def float_to_fixed_int(val, n, x):
    """Convert float scalar -> n-bit two's-complement integer representation (Q format).
       n = total bits, x = integer bits (including sign). fractional bits = n-x
    """
    frac_bits = n - x
    scale = 2 ** frac_bits
    # representable Q-range:
    max_val = (2 ** (x - 1)) - (1 / scale)   # slightly less than 2^(x-1)
    min_val = -1 * (2 ** (x - 1))
    v = float(val)
    v = min(max(v, min_val), max_val)
    scaled = int(round(v * scale))
    # two's complement conversion into unsigned storage if negative
    if scaled < 0:
        scaled = (1 << n) + scaled
    # mask to n bits
    scaled &= ((1 << n) - 1)
    return scaled

def fixed_int_to_float(fixed_val, n, x):
    """Convert n-bit two's-complement integer -> float for Q-format (x integer bits)."""
    # interpret two's complement signed int
    if fixed_val >= (1 << (n - 1)):
        fixed_val -= (1 << n)
    frac_bits = n - x
    return fixed_val / (2 ** frac_bits)

def int_to_bin_str(val, n):
    return format(val & ((1 << n) - 1), f'0{n}b')

# ---------- FINN-LIKE QUANTIZATION (adapted to Q-format) ----------
def quantize_to_qformat(arr, n, x):
    """Quantize arr to Q(n,x) format by rounding to nearest representable value."""
    frac_bits = n - x
    scale = 2 ** frac_bits
    min_val = - (2 ** (x - 1))
    max_val = (2 ** (x - 1)) - (1 / scale)
    clipped = np.clip(arr, min_val, max_val)
    quantized = np.round(clipped * scale) / scale
    return quantized

# ---------- LOAD TRAINING DATA ----------
if not Path(TRAIN_MEM_PATH).exists():
    print(f"ERROR: {TRAIN_MEM_PATH} not found. Place the file and re-run.", file=sys.stderr)
    sys.exit(1)

X = []
y = []

expected_line_length = input_dim * n_in + LABEL_BITS

with open(TRAIN_MEM_PATH, "r") as f:
    for i, line in enumerate(f):
        line = line.strip()
        if len(line) < expected_line_length:
            raise ValueError(f"Line {i} length {len(line)} less than expected {expected_line_length}")

        pixel_bits = line[: input_dim * n_in]
        label_bits = line[input_dim * n_in : input_dim * n_in + LABEL_BITS]

        image = []
        for j in range(input_dim):
            bin_chunk = pixel_bits[j*n_in:(j+1)*n_in]
            int_val = int(bin_chunk, 2)
            float_val = fixed_int_to_float(int_val, n_in, x_in)
            image.append(float_val)

        label = int(label_bits, 2)
        if label < 0 or label >= output_dim:
            raise ValueError(f"Label {label} out of range [0,{output_dim-1}] on line {i}")

        X.append(image)
        y.append(label)

X = np.array(X, dtype=np.float32)
y = np.array(y, dtype=np.int32)
print("Loaded data shapes:", X.shape, y.shape)
print("Label distribution:", np.unique(y, return_counts=True))

y_cat = to_categorical(y, num_classes=output_dim)

# Quick diagnostics
print("X stats: min, max, mean, std:", X.min(), X.max(), X.mean(), X.std())
print("Sample X[0]:", X[0][:8], "...")

# ---------- BUILD & TRAIN MODEL ----------
model = Sequential([
    Dense(hidden_dim1, input_dim=input_dim, activation='relu', kernel_regularizer=regularizers.l2(0.001)),
    Dense(hidden_dim2, activation='relu', kernel_regularizer=regularizers.l2(0.001)),
    Dense(output_dim, activation='softmax')
])

model.compile(optimizer=Adam(learning_rate=3e-4),
              loss='categorical_crossentropy',
              metrics=['accuracy'])

history = model.fit(X, y_cat, epochs=75, batch_size=16, verbose=1, validation_split=0.15, shuffle=True)

# ---------- QUANTIZE FOR PLOTTING ----------
def plot_weights_and_biases_ranges(quantized_weights, quantized_biases, layer_idx):
    weights_flat = quantized_weights.flatten()
    biases_flat = quantized_biases.flatten()

    plt.figure(figsize=(10, 4))
    plt.hist(weights_flat, bins=50, alpha=0.7)
    plt.title(f"Layer {layer_idx+1} Quantized Weights Distribution")
    plt.xlabel("Weight Value")
    plt.ylabel("Frequency")
    plt.grid(True)
    plt.axvline(np.min(weights_flat), color='red', linestyle='--', label=f"Min: {np.min(weights_flat):.4f}")
    plt.axvline(np.max(weights_flat), color='green', linestyle='--', label=f"Max: {np.max(weights_flat):.4f}")
    plt.legend()
    plt.tight_layout()
    plt.show()

    plt.figure(figsize=(10, 4))
    plt.hist(biases_flat, bins=50, alpha=0.7)
    plt.title(f"Layer {layer_idx+1} Quantized Biases Distribution")
    plt.xlabel("Bias Value")
    plt.ylabel("Frequency")
    plt.grid(True)
    plt.axvline(np.min(biases_flat), color='red', linestyle='--', label=f"Min: {np.min(biases_flat):.4f}")
    plt.axvline(np.max(biases_flat), color='green', linestyle='--', label=f"Max: {np.max(biases_flat):.4f}")
    plt.legend()
    plt.tight_layout()
    plt.show()

for layer_idx, layer in enumerate(model.layers):
    weights, biases = layer.get_weights()
    quantized_weights = quantize_to_qformat(weights, n_w, x_w)
    quantized_biases = quantize_to_qformat(biases, n_b, x_b)
    plot_weights_and_biases_ranges(quantized_weights, quantized_biases, layer_idx)

# ---------- PLOT LOSS & ACC ----------
plt.figure(figsize=(10,5))
plt.subplot(1,2,1)
plt.plot(history.history['loss'], label='Train Loss')
plt.plot(history.history.get('val_loss', []), label='Val Loss')
plt.xlabel('Epoch'); plt.ylabel('Loss'); plt.legend(); plt.grid(True)

plt.subplot(1,2,2)
plt.plot(history.history['accuracy'], label='Train Acc')
plt.plot(history.history.get('val_accuracy', []), label='Val Acc')
plt.xlabel('Epoch'); plt.ylabel('Accuracy'); plt.legend(); plt.grid(True)
plt.tight_layout()
plt.show()

# ---------- EXPORT QUANTIZED WEIGHTS & BIASES ----------
for layer_idx, layer in enumerate(model.layers):
    weights, biases = layer.get_weights()
    quantized_weights = quantize_to_qformat(weights, n_w, x_w).T  # shape -> (out_dim, in_dim) for export
    quantized_biases = quantize_to_qformat(biases, n_b, x_b)

    with open(f"layer{layer_idx+1}_weights.mem", "w") as wf:
        for row in quantized_weights:
            bin_row = ''.join([int_to_bin_str(float_to_fixed_int(w, n_w, x_w), n_w) for w in row])
            wf.write(bin_row + "\n")

    with open(f"layer{layer_idx+1}_biases.mem", "w") as bf:
        for b in quantized_biases:
            b_int = float_to_fixed_int(b, n_b, x_b)
            bf.write(int_to_bin_str(b_int, n_b) + "\n")

print("Export complete: quantized weight and bias .mem files written.")
