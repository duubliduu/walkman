import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:walkman/game/glide.dart';

void main() {
  group('lerpLatLng', () {
    final from = LatLng(60.0, 24.0);
    final to = LatLng(60.1, 24.2);

    test('at t=0 returns the start position', () {
      final p = lerpLatLng(from, to, 0);
      expect(p.latitude, closeTo(60.0, 1e-9));
      expect(p.longitude, closeTo(24.0, 1e-9));
    });

    test('at t=0.5 returns the midpoint', () {
      final p = lerpLatLng(from, to, 0.5);
      expect(p.latitude, closeTo(60.05, 1e-9));
      expect(p.longitude, closeTo(24.1, 1e-9));
    });

    test('at t=1 returns the end position', () {
      final p = lerpLatLng(from, to, 1);
      expect(p.latitude, closeTo(60.1, 1e-9));
      expect(p.longitude, closeTo(24.2, 1e-9));
    });

    test('clamps t outside [0, 1]', () {
      final below = lerpLatLng(from, to, -0.5);
      final above = lerpLatLng(from, to, 1.5);
      expect(below.latitude, closeTo(60.0, 1e-9));
      expect(above.latitude, closeTo(60.1, 1e-9));
    });
  });

  group('MarkerGlide', () {
    final from = LatLng(60.0, 24.0);
    final to = LatLng(60.1, 24.2);

    test('positionAt interpolates over the glide duration', () {
      final glide = MarkerGlide(
        from: from,
        to: to,
        startMs: 1000,
        durationMs: 1000,
      );

      expect(glide.positionAt(1000).latitude, closeTo(60.0, 1e-9));
      expect(glide.positionAt(1500).latitude, closeTo(60.05, 1e-9));
      expect(glide.positionAt(2000).latitude, closeTo(60.1, 1e-9));
    });

    test('isDone once the duration has elapsed', () {
      final glide = MarkerGlide(
        from: from,
        to: to,
        startMs: 1000,
        durationMs: 1000,
      );

      expect(glide.isDone(1500), isFalse);
      expect(glide.isDone(2000), isTrue);
      expect(glide.isDone(3000), isTrue);
    });
  });
}
