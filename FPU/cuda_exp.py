import math
import numpy as np

LN2 = 0.6931471805599453
INV_LN2 = 1.4426950408889634 

C1 = 1.0
C2 = 0.499999910593032
C3 = 0.16666588233947754
C4 = 0.0419443881213665
C5 = 0.008301110565662384

def exp_gpu(x: float) -> float:
    n = int(math.floor(x * INV_LN2 + 0.5))
    r = x - n * LN2

    poly = C1 + r * (C2 + r * (C3 + r * (C4 + r * C5)))

    return math.ldexp(poly, n)

def main():
    x = float(input("Enter a value for x: "))

    exp_numpy = math.exp(x)
    exp_gpu_like = exp_gpu(x)

    error = abs(exp_numpy - exp_gpu_like)
    rel_error = error / abs(exp_numpy) if exp_numpy != 0 else error

    print(f"\nNumPy exp:        {exp_numpy}")
    print(f"GPU-like exp:     {exp_gpu_like}")
    print(f"Absolute Error:   {error}")
    print(f"Relative Error:   {rel_error}")

if __name__ == "__main__":
    main()
