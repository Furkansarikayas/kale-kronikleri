import 'dart:math' as math;
import 'dart:typed_data';

/// Classic 2D Perlin noise generator with FBM and tileable variants.
///
/// All methods are pure functions after construction, making the generator
/// safe to reuse across frames without allocations.
class PerlinNoise {
  /// Permutation table (doubled to avoid index wrapping).
  late final Int32List _perm;

  /// Gradient vectors for 2D noise (unit-length, evenly spaced).
  static const List<List<double>> _gradients = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
    [1, 1],
    [-1, 1],
    [1, -1],
    [-1, -1],
    [0.7071067811865476, 0.7071067811865476],
    [-0.7071067811865476, 0.7071067811865476],
    [0.7071067811865476, -0.7071067811865476],
    [-0.7071067811865476, -0.7071067811865476],
  ];

  /// Creates a Perlin noise generator with the given [seed].
  PerlinNoise({int seed = 0}) {
    _perm = _buildPermutationTable(seed);
  }

  /// Builds a shuffled permutation table of size 512 (256 entries, doubled).
  Int32List _buildPermutationTable(int seed) {
    final rng = math.Random(seed);
    final p = List<int>.generate(256, (i) => i);

    // Fisher-Yates shuffle.
    for (int i = 255; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = p[i];
      p[i] = p[j];
      p[j] = tmp;
    }

    // Double the table so we never need to wrap indices.
    final perm = Int32List(512);
    for (int i = 0; i < 512; i++) {
      perm[i] = p[i & 255];
    }
    return perm;
  }

  // ---------------------------------------------------------------------------
  // Core helpers
  // ---------------------------------------------------------------------------

  /// Quintic fade curve: 6t^5 - 15t^4 + 10t^3.
  static double _fade(double t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
  }

  /// Linear interpolation.
  static double _lerp(double a, double b, double t) {
    return a + t * (b - a);
  }

  /// Dot product of a hashed gradient vector and the distance vector (dx, dy).
  double _grad(int hash, double dx, double dy) {
    final g = _gradients[hash % _gradients.length];
    return g[0] * dx + g[1] * dy;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns classic 2D Perlin noise in the range **[-1, 1]**.
  ///
  /// The noise field is continuous and differentiable everywhere, with zero
  /// values at integer lattice points.
  double noise2D(double x, double y) {
    // Unit square that contains the point.
    final xi = x.floor();
    final yi = y.floor();

    // Relative position inside the unit square.
    final xf = x - xi;
    final yf = y - yi;

    // Wrap to 0-255.
    final ix = xi & 255;
    final iy = yi & 255;

    // Hash the four corners.
    final h00 = _perm[_perm[ix] + iy];
    final h10 = _perm[_perm[ix + 1] + iy];
    final h01 = _perm[_perm[ix] + iy + 1];
    final h11 = _perm[_perm[ix + 1] + iy + 1];

    // Gradient dot products.
    final n00 = _grad(h00, xf, yf);
    final n10 = _grad(h10, xf - 1.0, yf);
    final n01 = _grad(h01, xf, yf - 1.0);
    final n11 = _grad(h11, xf - 1.0, yf - 1.0);

    // Fade curves for interpolation.
    final u = _fade(xf);
    final v = _fade(yf);

    // Bi-linear interpolation.
    return _lerp(
      _lerp(n00, n10, u),
      _lerp(n01, n11, u),
      v,
    );
  }

  /// Fractal Brownian Motion (fBm) layering of [noise2D].
  ///
  /// Returns a value in the range **[0, 1]** (remapped from the raw sum).
  ///
  /// * [octaves] -- number of noise layers (default 6).
  /// * [lacunarity] -- frequency multiplier per octave (default 2.0).
  /// * [gain] -- amplitude multiplier per octave, often called
  ///   *persistence* (default 0.5).
  double fbm(
    double x,
    double y, {
    int octaves = 6,
    double lacunarity = 2.0,
    double gain = 0.5,
  }) {
    double sum = 0.0;
    double amplitude = 1.0;
    double frequency = 1.0;
    double maxAmplitude = 0.0;

    for (int i = 0; i < octaves; i++) {
      sum += amplitude * noise2D(x * frequency, y * frequency);
      maxAmplitude += amplitude;
      amplitude *= gain;
      frequency *= lacunarity;
    }

    // Normalize from [-1, 1] to [0, 1].
    return (sum / maxAmplitude) * 0.5 + 0.5;
  }

  /// Tileable 2D Perlin noise that wraps seamlessly over the given [period].
  ///
  /// Returns a value in the range **[-1, 1]**, just like [noise2D].
  ///
  /// The trick projects the 2D coordinate onto two circles in 4D space so that
  /// the noise repeats every [period] units along both axes.
  double tileableNoise2D(double x, double y, double period) {
    // Map x and y to angles around circles whose circumference equals period.
    final twoPiOverP = 2.0 * math.pi / period;

    final angleX = x * twoPiOverP;
    final angleY = y * twoPiOverP;

    // Sample 4D Perlin noise on the surface of two circles.
    // Using radius = period / (2 * pi) keeps the spatial frequency close to
    // the non-tileable version.
    final r = period / (2.0 * math.pi);

    final nx = math.cos(angleX) * r;
    final ny = math.sin(angleX) * r;
    final nz = math.cos(angleY) * r;
    final nw = math.sin(angleY) * r;

    return _noise4D(nx, ny, nz, nw);
  }

  // ---------------------------------------------------------------------------
  // 4D Perlin noise (internal, used by tileableNoise2D)
  // ---------------------------------------------------------------------------

  /// Dot product of a hashed 4D gradient and a distance vector.
  static double _grad4D(int hash, double x, double y, double z, double w) {
    // Use the low 5 bits to choose among 32 gradient directions.
    final h = hash & 31;
    // Each gradient has three non-zero components chosen from {-1, +1}.
    final u = h < 24 ? x : y;
    final v = h < 16 ? y : z;
    final s = h < 8 ? z : w;
    return ((h & 1) == 0 ? u : -u) +
        ((h & 2) == 0 ? v : -v) +
        ((h & 4) == 0 ? s : -s);
  }

  /// Classic 4D Perlin noise in the range approximately [-1, 1].
  double _noise4D(double x, double y, double z, double w) {
    final xi = x.floor();
    final yi = y.floor();
    final zi = z.floor();
    final wi = w.floor();

    final xf = x - xi;
    final yf = y - yi;
    final zf = z - zi;
    final wf = w - wi;

    final ix = xi & 255;
    final iy = yi & 255;
    final iz = zi & 255;
    final iw = wi & 255;

    final u = _fade(xf);
    final v = _fade(yf);
    final s = _fade(zf);
    final t = _fade(wf);

    // Hash all 16 corners of the 4D hypercube.
    int hash4(int a, int b, int c, int d) =>
        _perm[_perm[_perm[_perm[a] + b] + c] + d];

    final n0000 = _grad4D(hash4(ix, iy, iz, iw), xf, yf, zf, wf);
    final n1000 = _grad4D(hash4(ix + 1, iy, iz, iw), xf - 1, yf, zf, wf);
    final n0100 = _grad4D(hash4(ix, iy + 1, iz, iw), xf, yf - 1, zf, wf);
    final n1100 = _grad4D(hash4(ix + 1, iy + 1, iz, iw), xf - 1, yf - 1, zf, wf);
    final n0010 = _grad4D(hash4(ix, iy, iz + 1, iw), xf, yf, zf - 1, wf);
    final n1010 = _grad4D(hash4(ix + 1, iy, iz + 1, iw), xf - 1, yf, zf - 1, wf);
    final n0110 = _grad4D(hash4(ix, iy + 1, iz + 1, iw), xf, yf - 1, zf - 1, wf);
    final n1110 =
        _grad4D(hash4(ix + 1, iy + 1, iz + 1, iw), xf - 1, yf - 1, zf - 1, wf);
    final n0001 = _grad4D(hash4(ix, iy, iz, iw + 1), xf, yf, zf, wf - 1);
    final n1001 = _grad4D(hash4(ix + 1, iy, iz, iw + 1), xf - 1, yf, zf, wf - 1);
    final n0101 = _grad4D(hash4(ix, iy + 1, iz, iw + 1), xf, yf - 1, zf, wf - 1);
    final n1101 =
        _grad4D(hash4(ix + 1, iy + 1, iz, iw + 1), xf - 1, yf - 1, zf, wf - 1);
    final n0011 = _grad4D(hash4(ix, iy, iz + 1, iw + 1), xf, yf, zf - 1, wf - 1);
    final n1011 =
        _grad4D(hash4(ix + 1, iy, iz + 1, iw + 1), xf - 1, yf, zf - 1, wf - 1);
    final n0111 =
        _grad4D(hash4(ix, iy + 1, iz + 1, iw + 1), xf, yf - 1, zf - 1, wf - 1);
    final n1111 = _grad4D(
        hash4(ix + 1, iy + 1, iz + 1, iw + 1), xf - 1, yf - 1, zf - 1, wf - 1);

    // Quadri-linear interpolation.
    final x1 = _lerp(n0000, n1000, u);
    final x2 = _lerp(n0100, n1100, u);
    final x3 = _lerp(n0010, n1010, u);
    final x4 = _lerp(n0110, n1110, u);
    final x5 = _lerp(n0001, n1001, u);
    final x6 = _lerp(n0101, n1101, u);
    final x7 = _lerp(n0011, n1011, u);
    final x8 = _lerp(n0111, n1111, u);

    final y1 = _lerp(x1, x2, v);
    final y2 = _lerp(x3, x4, v);
    final y3 = _lerp(x5, x6, v);
    final y4 = _lerp(x7, x8, v);

    final z1 = _lerp(y1, y2, s);
    final z2 = _lerp(y3, y4, s);

    return _lerp(z1, z2, t);
  }
}
