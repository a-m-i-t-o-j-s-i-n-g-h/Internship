import numpy as np

def exp_series(x, terms=20):

    result = 1.0
    term = 1.0
    for n in range(1, terms):
        term *= x / n 
        result += term
    return result

def main():
    x = float(input("Enter a value for x: "))

    exp_numpy = np.exp(x)

    exp_taylor = exp_series(x, terms=30)

    error = abs(exp_numpy - exp_taylor)

    print(f"\nUsing NumPy exp: {exp_numpy}")
    print(f"Using Taylor approx: {exp_taylor}")
    print(f"Absolute Error: {error}")

if __name__ == "__main__":
    main()
