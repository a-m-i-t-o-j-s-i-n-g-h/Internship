import numpy as np

def sqrt_basic(x, tol=1e-15, max_iter=1000):
    if x < 0:
        raise ValueError("Cannot compute square root of negative number")
    if x == 0:
        return 0
    
    guess = x / 2.0
    for _ in range(max_iter):
        new_guess = 0.5 * (guess + x / guess)
        if abs(new_guess - guess) < tol:
            return new_guess
        guess = new_guess
    return guess

x = float(input("Enter a positive number: "))

sqrt_numpy = np.sqrt(x)

sqrt_custom = sqrt_basic(x)

error = abs(sqrt_numpy - sqrt_custom)

print(f"Input: {x}")
print(f"NumPy sqrt: {sqrt_numpy}")
print(f"Custom sqrt: {sqrt_custom}")
print(f"Absolute error: {error}")
