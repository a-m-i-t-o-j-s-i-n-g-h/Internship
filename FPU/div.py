import numpy as np

LUT_SIZE = 256
lut = np.zeros(LUT_SIZE, dtype=np.float32)
for i in range(LUT_SIZE):
    m = 1.0 + i / LUT_SIZE
    lut[i] = 1.0 / m

def gpu_initial_guess(b):

    bf = np.float32(b)
    if bf == 0:
        return np.float32(np.inf)

    m, e = np.frexp(bf)
    m *= 2.0
    e -= 1 
    
    idx = int((m - 1.0) * LUT_SIZE)
    approx = lut[idx]

    return np.float32(approx * (2.0 ** -e))

def gpu_style_division(a, b, iterations=2):

    a = np.float32(a)
    b = np.float32(b)

    x = gpu_initial_guess(b)

    for _ in range(iterations):
        x = x * (2.0 - b * x)
    
    return float(a * x)

a = float(input("Enter numerator (a): "))
b = float(input("Enter denominator (b): "))

numpy_result = np.divide(a, b)
gpu_result = gpu_style_division(a, b)

error = abs(numpy_result - gpu_result)

print(f"\nResults:")
print(f"NumPy division      : {numpy_result}")
print(f"GPU-style division  : {gpu_result}")
print(f"Absolute error      : {error}")
