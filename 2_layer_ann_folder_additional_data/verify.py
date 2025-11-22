import numpy as np

# -------- Fixed-point Config --------
IN_BITS = 16      # Q8.8
MAC_BITS = 32     # Q16.16
INT_PART = 8
FRAC_PART = IN_BITS - INT_PART

# -------- Format Conversion --------
def binary_to_signed_int(bin_str):
    n = len(bin_str)
    val = int(bin_str, 2)
    if val >= (1 << (n - 1)):
        val -= (1 << n)
    return val

def signed_int_to_bin(val, n):
    if val < 0:
        val = (1 << n) + val
    return format(val & ((1 << n) - 1), f'0{n}b')

def relu(val):
    return max(0, val)

def truncate_q16_to_q8(val32):
    return val32 >> 8

def parse_input_bits(bitstring):
    assert len(bitstring) == 1028, "Must be 1028 bits"
    inputs = []
    for i in range(64):
        bin16 = bitstring[i*16:(i+1)*16]
        val = binary_to_signed_int(bin16)
        inputs.append(val)
    label = int(bitstring[-4:], 2)
    return np.array(inputs, dtype=np.int32), label

def print_outputs(label, vec, width):
    print(f"\n[{label}]")
    for i, val in enumerate(vec):
        binval = signed_int_to_bin(val, width)
        val_float = val / (2 ** (width // 2))
        print(f"  Neuron {i:02d}: {val_float:+.6f} --> {binval}")

def layer_forward(x, weights, biases, layer_name):
    mac = np.dot(weights, x) + biases
    print_outputs(f"{layer_name} - MAC Q16.16", mac, 32)

    truncated = np.array([truncate_q16_to_q8(v) for v in mac], dtype=np.int32)
    print_outputs(f"{layer_name} - Truncated Q8.8", truncated, 16)

    relu_out = np.array([relu(v) for v in truncated], dtype=np.int32)
    print_outputs(f"{layer_name} - ReLU Q8.8", relu_out, 16)
    return relu_out

def one_hot(vec):
    onehot = np.zeros_like(vec)
    onehot[np.argmax(vec)] = 1
    return onehot

def run_inference(bitstring):
    x, label = parse_input_bits(bitstring)
    print_outputs("Input Q8.8", x, 16)
    print(f"\n[True Label]: {label}")

    W1 = np.random.randint(-128, 128, size=(30, 64), dtype=np.int32)
    B1 = np.random.randint(-1000, 1000, size=(30,), dtype=np.int32)
    W2 = np.random.randint(-128, 128, size=(10, 30), dtype=np.int32)
    B2 = np.random.randint(-1000, 1000, size=(10,), dtype=np.int32)

    out1 = layer_forward(x, W1, B1, "Layer 1")
    out2 = layer_forward(out1, W2, B2, "Layer 2")

    pred = one_hot(out2)
    print_outputs("Final Output - ReLU Q8.8", out2, 16)
    print(f"\n[One-hot Prediction]: {pred.tolist()}")

# -------- Bitstring Input (manually set here) --------
bitstring = (
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001011001000000001101011100000000111000110000000000011010000000000000000000000000000000000000000000000000000000000000000000000000001100010000000000011110000000000101110000000000100101000000000000000000000000000000000000000000000000000000000000000000000000000000110000000000111100110000000011101111000000000000101100000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000110100000000011000101000000001010100000000000000000000000000000000000000000001101011100000000000100100000000000000000000000000000000000000000010110010000000011111110000000000000000000000000000000000000000000000000000000001011011000000000110001110000000011000111000000000100001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011")

run_inference(bitstring)
