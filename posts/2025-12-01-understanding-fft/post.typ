#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Understanding the Fast Fourier Transform (快速傅里叶变换)",
  date: "2025-12-01",
  tags: ("math", "algorithms", "signal-processing"),
  lang: "en",
  summary: "An introduction to the Fast Fourier Transform (FFT) --- from the DFT definition to the Cooley--Tukey algorithm, with Python code and complexity analysis.",
)

= Introduction
<introduction>
computational mathematics and signal processing. It converts a sequence
of $N$ complex numbers into another sequence of $N$ complex numbers,
revealing the frequency content of the original signal.

The #strong[Discrete Fourier Transform] (DFT)#footnote[See #emph[The
Scientist and Engineer's Guide to Digital Signal Processing] by Steven
W. Smith.] is one of the most important tools in computational
mathematics and signal processing. It converts a sequence of $N$ complex
numbers into another sequence of $N$ complex numbers, revealing the
frequency content of the original signal.

extbfDFT is the foundation of modern signal analysis.

For a historical perspective, see Cooley & Tukey, 1965.

然而，直接计算 DFT 需要 $O(N^2)$
次运算，对于大规模数据来说效率太低。\<!-- sidenote: DFT
的直接算法复杂度很高。 --\> 1965年，Cooley 和 Tukey
发表了#strong[快速傅里叶变换]（FFT）算法，将复杂度降低到
$O(N log N)$，使得频谱分析在实际工程中变得可行。\<!-- sidenote: FFT
是信号处理领域的革命性突破。 --\>

You can also use a sidenote in English: \<!-- sidenote: This is a right
margin comment for extra context. --\>

This article walks through the mathematical foundation of the DFT,
derives the radix-2 Cooley--Tukey FFT algorithm, and provides a Python
implementation.

= The Discrete Fourier Transform
<sec:dft>
We often write $omega_N = e^(- 2 pi i\/N)$, the #emph[primitive $N$-th
root of unity], so the transform becomes:
$ X_k = sum_(n = 0)^(N - 1) x_n thin omega_N^(k n) $

The inverse DFT recovers the original sequence:
$ x_n = 1 / N sum_(k = 0)^(N - 1) X_k thin omega_N^(- k n) $

== Key Properties
<key-properties>
The DFT satisfies several important properties:

- #strong[Linearity]:
  $upright(D F T)(alpha x + beta y)= alpha thin upright(D F T)(x)+ beta thin upright(D F T)(y)$

- #strong[Parseval's theorem]: $sum_n\|x_n\|^2= 1 / N sum_k\|X_k\|^2$

- #strong[Convolution theorem]: pointwise multiplication in the
  frequency domain corresponds to circular convolution in the time
  domain:
  $ upright(D F T)(x * y)= upright(D F T)(x)dot.op upright(D F T)(y) $

- #strong[Shift property]: 时域中的移位对应频域中的相位旋转。若
  $y_n = x_(n - m)$，则 $Y_k = omega_N^(m k) X_k$。

= The Cooley--Tukey FFT Algorithm
<sec:fft>
The key insight of the FFT is to exploit the symmetry and periodicity of
$omega_N$.

This gives us the #strong[butterfly operation]:
$ X_k & = E_k + omega_N^k thin O_k\
X_(k + N\/2) & = E_k - omega_N^k thin O_k $

Since $E_k$ and $O_k$ are periodic with period $N\/2$, we only need to
compute them for $k = 0\,1\,dots.h\,N\/2 - 1$.
通过递归地应用这一分解，我们可以将 $N$ 点 DFT 的计算 分解为 $log_2 N$
层蝶形运算，每层包含 $N\/2$ 次蝶形操作。

== Complexity Analysis
<complexity-analysis>
#figure(
  align(center)[#table(
    columns: 4,
    align: (left,center,center,center,),
    table.header([#strong[Algorithm]], [#strong[Multiplications]], [#strong[Additions]], [#strong[Total]],),
    table.hline(),
    [Naive DFT], [$N^2$], [$N(N - 1)$], [$O(N^2)$],
    [Radix-2 FFT], [$N / 2 log_2 N$], [$N log_2 N$], [$O(N log N)$],
  )]
  , caption: [Comparison of DFT and FFT computational complexity]
  , kind: table
  )

For a concrete example, consider $N = 2^20 approx 10^6$:

- Naive DFT: $tilde.op 10^12$ operations

- FFT: $tilde.op 10^7$ operations

- Speedup factor: $tilde.op 10^5$

= Python Implementation
<sec:python>
Below is a recursive radix-2 FFT implementation in Python.

```python
import numpy as np

def fft(x):
    """Compute the FFT of sequence x (length must be a power of 2)."""
    N = len(x)
    if N == 1:
        return x

    # Split into even and odd
    even = fft(x[0::2])
    odd  = fft(x[1::2])

    # Twiddle factors
    T = np.exp(-2j * np.pi * np.arange(N // 2) / N)

    # Butterfly
    return np.concatenate([
        even + T * odd,
        even - T * odd
    ])

# Example usage
if __name__ == "__main__":
    # Generate a signal: 50 Hz + 120 Hz
    fs = 1024           # Sampling rate
    t = np.arange(fs) / fs
    signal = np.sin(2 * np.pi * 50 * t) + 0.5 * np.sin(2 * np.pi * 120 * t)

    # Compute FFT
    spectrum = fft(signal)
    freqs = np.arange(fs) * fs / fs
    magnitudes = np.abs(spectrum) / fs

    print(f"Peak frequencies: {freqs[np.argsort(magnitudes)[-4:]]} Hz")
```

We can verify our implementation against NumPy's built-in FFT:

```python
x = np.random.random(1024)
assert np.allclose(fft(x), np.fft.fft(x))
print("FFT implementation verified!")
```

= Applications
<sec:apps>
The FFT has far-reaching applications across many domains:

+ #strong[Signal processing]: spectral analysis, filtering, compression
  (e.g., MP3, JPEG)

+ #strong[Polynomial multiplication]: multiplying two degree-$n$
  polynomials in $O(n log n)$ instead of $O(n^2)$

+ #strong[Large integer multiplication]: the Schönhage--Strassen
  algorithm uses FFT to multiply $n$-digit integers in
  $O(n log n log log n)$

+ #strong[Partial differential equations]: 谱方法利用 FFT
  在频域中高效求解偏微分方程， 在流体力学和量子力学模拟中广泛使用

+ #strong[Convolution]: fast computation of convolutions via the
  convolution theorem, used in deep learning (convolutional neural
  networks)

= Conclusion
<conclusion>
For more on the DFT, refer back to Section~. For the FFT algorithm, see
Section~. For code, see Section~. For real-world uses, see Section~.

FFT 是计算数学中最优美、最实用的算法之一。它将 DFT 的计算复杂度从
$O(N^2)$ 降低到 $O(N log N)$，使得大规模频谱分析成为可能。From
signal processing to number theory, from image compression to solving
PDEs, the FFT remains an indispensable tool in the modern computational
toolkit.

The key idea --- #emph[divide and conquer via the symmetry of roots of
unity] --- is both mathematically elegant and practically powerful.
Understanding the FFT provides deep insight into the interplay between
the time domain and the frequency domain, a duality that lies at the
heart of much of applied mathematics.
