import numpy as np
import os # Import os for checking file existence

# ---------- PARAMETERS ----------
# These parameters MUST match the ones used during the training/export phase
# where train_88.mem, test_88.mem, and the weight/bias files were generated.

# Dimensions of the network layers
dims = [64, 50, 30, 10]

# Fixed-point format parameters for various data types during inference
# NOTE: All numbers are now treated as integers. The 'X' value indicates the number
# of bits in the integer part (including sign bit), and (N-X) is fractional bits.

# Input Data from test_88.mem: Q16.16 (N=32, I=16, F=16)
N_IN_DATA, X_IN_DATA = 32, 16
F_IN_DATA = N_IN_DATA - X_IN_DATA # Fractional bits for input data

# Weights from layerX_weights.mem: Q16.16 (N=32, I=16, F=16)
N_W, X_W = 32, 16
F_W = N_W - X_W # Fractional bits for weights

# Biases from layerX_biases.mem: Q32.32 (N=64, I=32, F=32)
N_B, X_B = 64, 32
F_B = N_B - X_B # Fractional bits for biases

# Activations (Layer Outputs): Q8.8 (N=16, I=8, F=8) - TARGET for intermediate layers
N_A, X_A = 32, 16
F_A = N_A - X_A # Fractional bits for activations

# Define the accumulator precision for products and sums
# Product (Input * Weight): Q(X_IN_DATA + X_W).(F_IN_DATA + F_W) = Q32.32
F_PROD = F_IN_DATA + F_W # Fractional bits for product = 16 + 16 = 32

# Max integer bits for accumulator (worst case sum of 64 products)
# I_ACC = X_IN_DATA + X_W + ceil(log2(max_fan_in)) = 16 + 16 + ceil(log2(64)) = 32 + 6 = 38
# Total bits needed for accumulator = I_ACC + F_PROD = 38 + 32 = 70 bits.
# Since np.int64 is 64 bits, we need to be mindful of potential accumulator overflow if max
# range is hit. For this simulation, np.int64 will be used, and we rely on QAT's
# learned ranges to fit.

# ---------- Fixed-Point Helpers (Operating on integer representations) ----------

def float_to_fixed_int(val, n_total_bits, n_integer_bits):
    """Converts a float to its fixed-point integer representation (signed 2's complement)."""
    n_fractional_bits = n_total_bits - n_integer_bits
    scale = 2**n_fractional_bits
    
    scaled = round(val * scale)
    
    # Clamp to valid fixed-point integer range
    max_representable_int = (2**(n_total_bits - 1)) - 1
    min_representable_int = -(2**(n_total_bits - 1))
    clamped_val = int(min(max(scaled, min_representable_int), max_representable_int))
    
    return clamped_val

def fixed_bin_to_fixed_int(bin_str, n_total_bits, n_integer_bits):
    """Converts a 2's complement binary string to its fixed-point integer value."""
    val_int = int(bin_str, 2)
    # Handle two's complement for negative numbers
    if val_int >= (1 << (n_total_bits - 1)):
        val_int -= (1 << n_total_bits)
    return val_int

def fixed_int_to_float(fixed_int_val, n_total_bits, n_integer_bits):
    """Converts a fixed-point integer back to a float for verification/softmax."""
    n_fractional_bits = n_total_bits - n_integer_bits
    return float(fixed_int_val) / (2**n_fractional_bits)

def quantize_and_saturate_fixed_int(val_int, current_frac_bits, target_n_total_bits, target_n_integer_bits):
    """
    Quantizes (rounds and truncates/shifts) and saturates a fixed-point integer
    from one fractional format to another, then saturates to the target total bits.
    This simulates the output scaling for activations.
    """
    target_n_fractional_bits = target_n_total_bits - target_n_integer_bits
    
    # Calculate the shift amount
    shift_amount = current_frac_bits - target_n_fractional_bits
    
    if shift_amount < 0:
        # This means the target precision is higher; ideally, this shouldn't happen
        # without up-scaling or introducing more fractional bits.
        # For simplicity, if this occurs, we'll shift left (multiply).
        # Hardware usually aims to go from wider to narrower or same precision.
        # This scenario would require multiplying by 2^(-shift_amount).
        print(f"Warning: Upscaling fixed-point precision from F={current_frac_bits} to F={target_n_fractional_bits}. This might lose accuracy if not intended.")
        shifted_val = val_int << abs(shift_amount)
    else:
        # Rounding: Add half the LSB of the shifted-out part before shifting.
        # This implements "round to nearest, ties away from zero" for positive numbers.
        # For signed numbers, adding (1 << (shift_amount - 1)) before signed right shift (>>)
        # handles round-to-nearest-half-up fairly well for both positive/negative.
        
        # We target "half rounding at 9th bit before truncation", which implies
        # adding 0.5 (scaled) before truncation for the target 8 fractional bits.
        # The 9th bit is the first bit to be truncated after the desired 8 fractional bits.
        # Adding 0.5 at the target LSB scale means adding 1 << (shift_amount - 1)
        
        round_bias = 1 << (shift_amount - 1) if shift_amount > 0 else 0
        
        # Apply rounding bias and then shift
        if val_int >= 0:
            rounded_val = val_int + round_bias
        else:
            rounded_val = val_int - round_bias # For negative numbers, add to make them more negative for rounding towards zero
        
        shifted_val = rounded_val >> shift_amount
    
    # Saturation (clamping to the target fixed-point range)
    max_representable_int = (2**(target_n_total_bits - 1)) - 1
    min_representable_int = -(2**(target_n_total_bits - 1))
    
    saturated_val = np.clip(shifted_val, min_representable_int, max_representable_int).astype(np.int32)
    
    return saturated_val

# ---------- LOAD WEIGHTS AND BIASES (as fixed-point integers) ----------
weights_fxp_int = []
biases_fxp_int = []

# Load weights for all layers
for i in range(len(dims) - 1):
    weights_filename = f"layer{i+1}_weights.mem"
    if not os.path.exists(weights_filename):
        print(f"Error: Weight file '{weights_filename}' not found. Please ensure export was successful.")
        exit()

    layer_weights = []
    with open(weights_filename, "r") as f:
        for line in f:
            row_weights = []
            # Each weight is N_W bits long (32 bits for Q16.16)
            for j in range(dims[i]): # dims[i] is input_dim for this layer's weights
                bin_chunk = line[j*N_W:(j+1)*N_W]
                fxp_val = fixed_bin_to_fixed_int(bin_chunk, N_W, X_W)
                row_weights.append(fxp_val)
            layer_weights.append(row_weights)
    # Weights are exported as (out_dim, in_dim) and need to be transposed for dot product
    # in numpy, but since we are doing manual matrix mult, keep as is
    weights_fxp_int.append(np.array(layer_weights, dtype=np.int32))

# Load biases for all layers
for i in range(len(dims) - 1):
    biases_filename = f"layer{i+1}_biases.mem"
    if not os.path.exists(biases_filename):
        print(f"Error: Bias file '{biases_filename}' not found. Please ensure export was successful.")
        exit()

    layer_biases = []
    with open(biases_filename, "r") as f:
        for line in f:
            bin_chunk = line.strip()
            fxp_val = fixed_bin_to_fixed_int(bin_chunk, N_B, X_B)
            layer_biases.append(fxp_val)
    biases_fxp_int.append(np.array(layer_biases, dtype=np.int64))

print("Fixed-point weights and biases loaded successfully.")


# ---------- LOAD TEST DATA (as fixed-point integers) ----------
X_test_fxp_int = []
y_test = []

test_data_filename = "test_88.mem"
if not os.path.exists(test_data_filename):
    print(f"Error: Test data file '{test_data_filename}' not found. Please ensure it's in the same directory.")
    exit()

with open(test_data_filename, "r") as f:
    for line in f:
        line = line.strip()
        pixel_bits = line[:-4] # 64 pixels * N_IN_DATA bits
        label_bits = line[-4:]

        image_fxp = [fixed_bin_to_fixed_int(pixel_bits[i*N_IN_DATA:(i+1)*N_IN_DATA], N_IN_DATA, X_IN_DATA) for i in range(dims[0])]
        label = int(label_bits, 2)

        X_test_fxp_int.append(image_fxp)
        y_test.append(label)

X_test_fxp_int = np.array(X_test_fxp_int, dtype=np.int32) # Ensure it's np.int64
y_test = np.array(y_test, dtype=np.int32)
print(f"Loaded {len(X_test_fxp_int)} test samples as fixed-point integers.")

# ---------- INFERENCE (Pure Fixed-Point Integer Arithmetic) ----------
print("\nStarting pure fixed-point integer inference...")
correct = 0
total = len(X_test_fxp_int)

for idx in range(total):
    # Initial input for the first layer (Q8.8 after scaling)
    # X_test_fxp_int is Q16.16. Needs to be quantized to Q8.8
    current_input_fxp = np.array([
        quantize_and_saturate_fixed_int(val, F_IN_DATA, N_A, X_A) for val in X_test_fxp_int[idx]
    ], dtype=np.int32)
    
    # Forward pass through the network layers
    for l in range(len(weights_fxp_int)):
        current_weights = weights_fxp_int[l] # Q16.16
        current_biases = biases_fxp_int[l]   # Q32.32

        # Output of the current layer will be stored here
        layer_output_fxp = np.zeros(dims[l+1], dtype=np.int64)

        # Iterate over output neurons of the current layer
        for out_neuron_idx in range(dims[l+1]):
            accumulator = np.int64(0) # Initialize accumulator for each neuron (using np.int64 for wide range)

            # Iterate over inputs to this neuron (fan-in)
            for in_neuron_idx in range(dims[l]):
                input_val = current_input_fxp[in_neuron_idx] # Q8.8
                weight_val = current_weights[out_neuron_idx, in_neuron_idx] # Q16.16 (weights stored as (out, in))

                # Fixed-point multiplication: (Q8.8) * (Q16.16)
                # Raw product is scaled by 2^(F_A + F_W) = 2^(8 + 16) = 2^24
                product = input_val * weight_val
                print(f"Product: {product.dtype}")

                
                # Accumulate the products
                accumulator += product
            
            # After accumulation, the accumulator is scaled by 2^24.
            # Add bias (Q32.32), must align fractional points.
            # Bias needs to be right-shifted from F_B (32) to F_PROD (24).
            # Shift amount: F_B - F_PROD = 32 - 24 = 8 bits.
            bias_val = current_biases[out_neuron_idx]
            bias_shifted = bias_val >> (F_B - F_PROD) # Align bias fractional part to accumulator's (2^24)
            
            accumulator_with_bias = accumulator + bias_shifted
            
            # Apply re-quantization/truncation and saturation to Q8.8 for the activation
            # current_frac_bits = F_PROD (24)
            # target_n_total_bits = N_A (16)
            # target_n_integer_bits = X_A (8)
            quantized_activated_val = quantize_and_saturate_fixed_int(
                accumulator_with_bias, F_PROD, N_A, X_A
            )
            
            # Apply ReLU (for all but the last layer)
            if l < len(weights_fxp_int) - 1:
                layer_output_fxp[out_neuron_idx] = np.maximum(np.int64(0), quantized_activated_val)
            else:
                # Last layer: No ReLU. Store the quantized value for Softmax.
                # Softmax itself is usually performed in floating point after the fixed-point computations.
                layer_output_fxp[out_neuron_idx] = quantized_activated_val
        
        current_input_fxp = layer_output_fxp # Output of this layer becomes input for next

    # Final Softmax (convert last layer's fixed-point outputs to float for Softmax)
    # The output of the last hidden layer is now current_input_fxp, which is Q8.8 fixed-point integers.
    # Convert them to floats for standard softmax calculation.
    final_layer_floats = np.array([fixed_int_to_float(val, N_A, X_A) for val in current_input_fxp])
    
    # Apply Softmax
    exp_values = np.exp(final_layer_floats - np.max(final_layer_floats)) # Subtract max for numerical stability
    probabilities = exp_values / np.sum(exp_values)

    predicted_label = np.argmax(probabilities)
    true_label = y_test[idx]

    if predicted_label == true_label:
        correct += 1

accuracy = correct / total
print(f"Pure fixed-point integer inference complete. Accuracy: {accuracy*100:.2f}%")