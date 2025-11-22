import numpy as np

# ---------- LOAD DATA ----------
X_train = np.load('X_train_8x8.npy')  # shape: (N, 8, 8)
Y_train = np.load('Y_train_8x8.npy')  # shape: (N,)
X_test  = np.load('X_test_8x8.npy')
Y_test  = np.load('Y_test_8x8.npy')

# ---------- FIXED-POINT SETTINGS ----------
n_bits = 16         # total bits for Q8.8
int_bits = 8        # 1 sign bit + 7 integer bits
frac_bits = n_bits - int_bits  # = 8 fractional bits

# ---------- CONVERSION FUNCTION ----------
def pixel_to_q88_bin(p):
    """
    Normalize pixel [0–255] to [0,1], then convert to signed Q8.8 (16-bit 2's complement)
    """
    # Normalize
    normalized = p / 255.0

    # Convert to fixed-point
    scale = 2 ** frac_bits
    fixed_val = int(round(normalized * scale))

    # Clamp to valid Q8.8 range
    max_val = (1 << (n_bits - 1)) - 1   # +32767
    min_val = -(1 << (n_bits - 1))      # -32768
    fixed_val = min(max(fixed_val, min_val), max_val)

    # Convert to 2's complement binary
    if fixed_val < 0:
        fixed_val = (1 << n_bits) + fixed_val
    return format(fixed_val, f'0{n_bits}b')  # 16-bit string

# ---------- ENCODE SINGLE IMAGE LINE ----------
def encode_image_line_q88(image, label):
    flat = image.flatten()  # shape: (64,)
    bits = ''.join([pixel_to_q88_bin(p) for p in flat])  # 64 * 16 = 1024 bits
    label_bits = format(int(label), '04b')  # 4-bit label
    return bits + label_bits  # Total: 1028 bits

# ---------- WRITE TO FILE ----------
def write_file_q88(X, Y, filename):
    with open(filename, 'w') as f:
        for img, lbl in zip(X, Y):
            line = encode_image_line_q88(img, lbl)
            f.write(line + '\n')

# ---------- GENERATE OUTPUT FILES ----------
write_file_q88(X_train, Y_train, 'train_88.mem')
write_file_q88(X_test,  Y_test,  'test_88.mem')
