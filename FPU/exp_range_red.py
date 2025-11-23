import math
import sys

try:
    import numpy as np
except ImportError:
    np = None

MAX_LOG = math.log(sys.float_info.max)   # ~709.78
MIN_LOG = math.log(sys.float_info.min)   # ~-745.13

def numpy_exp(x):
    if np is not None:
        return float(np.exp(x))
    else:
        try:
            return math.exp(x)
        except OverflowError:
            return float('inf') if x > 0 else 0.0

def exp_taylor_basic(x, terms=30):

    result = 1.0
    term = 1.0
    for n in range(1, terms):
        term = term * x / n
        result += term
    return result

def exp_gpu_like(x, degree=7):

    if x > MAX_LOG:
        return float('inf')
    if x < MIN_LOG:
        return 0.0

    ln2 = math.log(2.0)
    inv_ln2 = 1.0 / ln2

    k = int(math.floor(x * inv_ln2 + 0.5))
    r = x - k * ln2

    coeffs_by_degree = {
        1:  [1.0, 1.0],                                
        2:  [1.0/2.0, 1.0, 1.0],
        3:  [1.0/6.0, 1.0/2.0, 1.0, 1.0],
        4:  [1.0/24.0, 1.0/6.0, 1.0/2.0, 1.0, 1.0],
        5:  [1.0/120.0, 1.0/24.0, 1.0/6.0, 1.0/2.0, 1.0, 1.0],
        6:  [1.0/720.0, 1.0/120.0, 1.0/24.0, 1.0/6.0, 1.0/2.0, 1.0, 1.0],
        7:  [1.0/5040.0, 1.0/720.0, 1.0/120.0, 1.0/24.0, 1.0/6.0, 1.0/2.0, 1.0, 1.0],
        8:  [1.0/40320.0,1.0/5040.0,1.0/720.0,1.0/120.0,1.0/24.0,1.0/6.0,1.0/2.0,1.0,1.0],
        9:  [1.0/362880.0,1.0/40320.0,1.0/5040.0,1.0/720.0,1.0/120.0,1.0/24.0,1.0/6.0,1.0/2.0,1.0,1.0],
    }

    if degree < 1:
        degree = 1
    if degree > 9:
        degree = 9
    coeffs = coeffs_by_degree[degree]

    p = coeffs[0]
    for a in coeffs[1:]:
        p = p * r + a

    try:
        result = math.ldexp(p, k)
    except OverflowError:
        result = float('inf') if x > 0 else 0.0

    return result

def compare_and_print(x, degree=7, taylor_terms=30):
    ref = numpy_exp(x)
    approx_gpu = exp_gpu_like(x, degree=degree)
    approx_taylor = exp_taylor_basic(x, terms=taylor_terms)

    def rel_err(a, b):
        if math.isfinite(b) and b != 0.0:
            return abs(a - b) / abs(b)
        elif b == 0.0:
            return abs(a - b)
        else:
            return float('nan')

    abs_err_gpu = abs(ref - approx_gpu) if math.isfinite(ref) else float('nan')
    rel_err_gpu = rel_err(approx_gpu, ref)
    abs_err_taylor = abs(ref - approx_taylor) if math.isfinite(ref) else float('nan')
    rel_err_taylor = rel_err(approx_taylor, ref)

    print(f"\nInput x = {x!r}")
    print(f"Reference (numpy/math.exp): {ref!r}")
    print(f"GPU-like approx (degree={degree}): {approx_gpu!r}")
    print(f"  Absolute error: {abs_err_gpu}")
    print(f"  Relative error: {rel_err_gpu}")
    print(f"Naive Taylor (terms={taylor_terms}): {approx_taylor!r}")
    print(f"  Absolute error: {abs_err_taylor}")
    print(f"  Relative error: {rel_err_taylor}")


def main():
    if len(sys.argv) >= 2:
        try:
            x = float(sys.argv[1])
        except Exception as e:
            print("Couldn't parse command-line input as float:", e)
            return
    else:
        try:
            s = input("Enter a value for x (e.g. 1.0, -20, 700): ").strip()
            x = float(s)
        except Exception as e:
            print("Bad input:", e)
            return


    degree = 7
    taylor_terms = 30

    compare_and_print(x, degree=degree, taylor_terms=taylor_terms)

    demo_values = [0.0, 1.0, -1.0, 10.0, 20.0, 50.0, 100.0]
    print("\nQuick demo (several values):")
    for v in demo_values:
        try:
            ref = numpy_exp(v)
        except Exception:
            ref = float('inf') if v > 0 else 0.0
        approx = exp_gpu_like(v, degree=degree)
        if math.isfinite(ref) and ref != 0:
            re = abs(ref - approx) / abs(ref)
            ae = abs(ref - approx)
        else:
            re = float('nan'); ae = float('nan')
        print(f" x={v:7}  ref={'{:.6g}'.format(ref):>12}  gpu_approx={'{:.6g}'.format(approx):>12}  rel_err={re:.3e}  abs_err={ae:.3g}")

if __name__ == "__main__":
    main()
