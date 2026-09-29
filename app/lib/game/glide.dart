import 'package:latlong2/latlong.dart';

import 'constants.dart';

/// Linearly interpolates between [from] and [to] at fraction [t] (clamped to
/// [0, 1]). `t = 0` returns [from], `t = 1` returns [to].
LatLng lerpLatLng(LatLng from, LatLng to, double t) {
  final k = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
  return LatLng(
    from.latitude + (to.latitude - from.latitude) * k,
    from.longitude + (to.longitude - from.longitude) * k,
  );
}

/// Animates a marker from [from] to [to] over [durationMs] milliseconds,
/// starting at [startMs] (epoch milliseconds). Display-only: game logic
/// should keep using the true (non-interpolated) position.
class MarkerGlide {
  final LatLng from;
  final LatLng to;
  final int startMs;
  final int durationMs;

  const MarkerGlide({
    required this.from,
    required this.to,
    required this.startMs,
    this.durationMs = glideDurationMs,
  });

  /// The interpolated position at [nowMs].
  LatLng positionAt(int nowMs) {
    if (durationMs <= 0) return to;
    return lerpLatLng(from, to, (nowMs - startMs) / durationMs);
  }

  /// Whether the glide has reached [to] by [nowMs].
  bool isDone(int nowMs) => nowMs - startMs >= durationMs;
}
