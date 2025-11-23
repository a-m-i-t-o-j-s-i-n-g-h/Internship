import numpy as np

LN2 = np.log(2.0)

def exp_gpu(x):
    n = int(x / LN2)
    r = x - n * LN2
    r2 = r * r
    poly = 1 + r + r2/2 + r2*r/6 + r2*r2/24

    return np.ldexp(poly, n)

def main():
    x = float(input("Enter a value for x: "))

    exp_numpy = np.exp(x)
    exp_gpu_like = exp_gpu(x)

    error = abs(exp_numpy - exp_gpu_like)
    rel_error = error/exp_numpy

    print(f"\nNumPy exp: {exp_numpy}")
    print(f"GPU-like exp approx: {exp_gpu_like}")
    print(f"Absolute Error: {error}")
    print(f"Relative Error: {rel_error}")

if __name__ == "__main__":
    main()
