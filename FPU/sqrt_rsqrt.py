import numpy as np

def rsqrt_newton(x, iterations=3):
    if x <= 0:
        raise ValueError("Input must be positive.")

    y = 1.0 / (x ** 0.5) 
    for _ in range(iterations):
        y = y * (1.5 - 0.5 * x * y * y)
    return y

def sqrt_gpu_style(x):
    return x * rsqrt_newton(x)

x = float(input("Enter a positive number: "))

sqrt_numpy = np.sqrt(x)

sqrt_gpu = sqrt_gpu_style(x)

error = abs(sqrt_numpy - sqrt_gpu)

print("\n--- Results ---")
print(f"Input value: {x}")
print(f"NumPy sqrt:      {sqrt_numpy}")
print(f"GPU-style sqrt:  {sqrt_gpu}")
print(f"Absolute error:  {error}")