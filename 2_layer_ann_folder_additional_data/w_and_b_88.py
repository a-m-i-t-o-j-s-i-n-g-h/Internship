import numpy as np
from tensorflow.keras import layers, regularizers  # type: ignore
from tensorflow.keras.models import Sequential     # type: ignore
from tensorflow.keras.layers import Dense          # type: ignore
from tensorflow.keras.utils import to_categorical  # type: ignore
from tensorflow.keras.optimizers import Adam       # type: ignore
import matplotlib.pyplot as plt

# ---------- PARAMETERS ----------
input_dim = 64
hidden_dim1 = 50
#hidden_dim2 = 30
output_dim = 10
n_w, x_w = 16, 8   # Q8.8 for weights
n_b, x_b = 32, 16   # Q8.8 for biases

# ---------- FIXED-POINT HELPERS ----------
def float_to_fixed_int(val, n, x):
    frac_bits = n - x
    scale = 2 ** frac_bits
    max_val = (2 ** (x - 1)) - 1 / scale
    min_val = -1 * (2 ** (x - 1))
    val = min(max(val, min_val), max_val)
    scaled = int(round(val * scale))
    if scaled < 0:
        scaled = (1 << n) + scaled
    return scaled

def fixed_int_to_float(fixed_val, n, x):
    if fixed_val >= (1 << (n - 1)):
        fixed_val -= (1 << n)
    return fixed_val / (2 ** (n - x))

def int_to_bin_str(val, n):
    return format(val, f'0{n}b')

def bin_str_to_int(bin_str):
    return int(bin_str, 2)

# ---------- LOAD TRAINING DATA ----------
X = []
y = []

with open("train_88.mem", "r") as f:
    for line in f:
        line = line.strip()
        pixel_bits = line[:-4]         # 64 pixels * 16 bits = 1024 bits
        label_bits = line[-4:]         # last 4 bits for label

        image = []
        for i in range(input_dim):
            bin_chunk = pixel_bits[i*16:(i+1)*16]
            int_val = bin_str_to_int(bin_chunk)
            float_val = fixed_int_to_float(int_val, n_w, x_w)
            image.append(float_val)

        label = int(label_bits, 2)
        X.append(image)
        y.append(label)

X = np.array(X, dtype=np.float32)
y = np.array(y, dtype=np.int32)
y_cat = to_categorical(y, num_classes=output_dim)

# ---------- BUILD & TRAIN MODEL ----------
model = Sequential()
model.add(Dense(hidden_dim1, input_dim=input_dim, activation='relu',
                kernel_regularizer=regularizers.L2(0.001)))
#model.add(Dense(hidden_dim2, activation='relu',
#                kernel_regularizer=regularizers.L2(0.001)))
model.add(Dense(output_dim, activation='softmax'))

model.compile(optimizer=Adam(learning_rate=0.003),
              loss='categorical_crossentropy', metrics=['accuracy'])

history = model.fit(X, y_cat, epochs=50, batch_size=16, verbose=1)

# ---------- PLOT LOSS ----------
plt.figure(figsize=(8, 5))
plt.plot(history.history['loss'], label='Training Loss', color='red', linewidth=2)
plt.xlabel('Epoch')
plt.ylabel('Loss')
plt.title('Training Loss Curve')
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.show()

# ---------- EXPORT WEIGHTS & BIASES IN Q8.8 ----------
for layer_idx, layer in enumerate(model.layers):
    weights, biases = layer.get_weights()
    weights = weights.T  # shape: (out_dim, in_dim)

    # Export weights
    with open(f"layer{layer_idx+1}_weights.mem", "w") as wf:
        for row in weights:
            bin_row = ''.join([
                int_to_bin_str(float_to_fixed_int(w, n_w, x_w), n_w)
                for w in row
            ])
            wf.write(bin_row + "\n")

    # Export biases
    with open(f"layer{layer_idx+1}_biases.mem", "w") as bf:
        for b in biases:
            b_int = float_to_fixed_int(b, n_b, x_b)
            bf.write(int_to_bin_str(b_int, n_b) + "\n")
