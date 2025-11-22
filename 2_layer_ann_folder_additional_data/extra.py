def float_to_fixed_int(val, n, x):
    frac_bits = n - x
    scale = 2 ** frac_bits
    max_val = (2 ** (x - 1)) - 1 / scale
    min_val = -1 * (2 ** (x - 1))
    
    # Clip the input to the representable range
    val = min(max(val, min_val), max_val)

    # Scale and round to nearest integer
    scaled = int(round(val * scale))
    
    # Wrap negative numbers for n-bit signed integer representation
    if scaled < 0:
        scaled = (1 << n) + scaled

    return scaled

# === Main Code ===
if __name__ == "__main__":
    val = float(input("Enter the float value: "))
    n = int(input("Enter total number of bits (n): "))
    x = int(input("Enter number of integer bits (x): "))

    fixed_int = float_to_fixed_int(val, n, x)
    print(f"Fixed-point integer representation: {fixed_int}")

