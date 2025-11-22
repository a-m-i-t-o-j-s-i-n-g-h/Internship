import math

def fixed_to_float(val, datawidth, int_bits):
    # Convert signed fixed-point (2's complement) to float
    if val & (1 << (datawidth - 1)):
        val = val - (1 << datawidth)
    scale = 2 ** (datawidth - int_bits)
    return val / scale

def float_to_fixed(val, total_bits, int_bits):
    # Convert float to signed fixed-point (2's complement)
    scale = 2 ** (total_bits - int_bits)
    fixed_val = int(round(val * scale))
    # Handle overflow clipping
    max_val = (1 << (total_bits - 1)) - 1
    min_val = -1 << (total_bits - 1)
    if fixed_val > max_val:
        fixed_val = max_val
    elif fixed_val < min_val:
        fixed_val = min_val
    return fixed_val & ((1 << total_bits) - 1)

def generate_exp_lut(datawidth, int_part_input, filename="exp_lut.mem"):
    frac_part_input = datawidth - int_part_input
    int_part_output = 2 * int_part_input
    frac_part_output = 2 * frac_part_input
    out_datawidth = int_part_output + frac_part_output

    with open(filename, 'w') as f:
        for i in range(2 ** datawidth):
            input_float = fixed_to_float(i, datawidth, int_part_input)
            exp_val = math.exp(input_float)

            exp_fixed = float_to_fixed(exp_val, out_datawidth, int_part_output)

            input_bin = format(i, f'0{datawidth}b')
            output_bin = format(exp_fixed, f'0{out_datawidth}b')

            f.write(f"{output_bin}\n")

    print(f"[+] Lookup table saved to '{filename}'.")

# Example usage
generate_exp_lut(datawidth=11, int_part_input=4)
