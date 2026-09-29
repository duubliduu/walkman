import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/game/geo.dart';
import 'package:walkman/game/snap.dart';

void main() {
  group('snapToRoad', () {
    test('snaps onto a segment interior', () {
      final roadLines = [
        [const Pt(0, 0), const Pt(100, 0)],
      ];
      final result = snapToRoad(roadLines, const Pt(50, 5));

      expect(result, isNotNull);
      expect(result!.xy.x, closeTo(50, 1e-9));
      expect(result.xy.y, closeTo(0, 1e-9));
      expect(result.lineIndex, 0);
    });

    test('clamps the projection to the segment endpoints', () {
      final roadLines = [
        [const Pt(0, 0), const Pt(100, 0)],
      ];
      // Off the start of the segment: nearest point is the (0,0) endpoint,
      // not the extrapolated line.
      final result = snapToRoad(roadLines, const Pt(-10, 5));

      expect(result, isNotNull);
      expect(result!.xy, const Pt(0, 0));
    });

    test('returns null beyond snapMax (25 m) from any road', () {
      final roadLines = [
        [const Pt(0, 0), const Pt(100, 0)],
      ];
      final result = snapToRoad(roadLines, const Pt(50, 30));

      expect(result, isNull);
    });

    test('prefers the current road within the switch penalty (5 m)', () {
      // Two parallel roads 10 m apart; the point is 3 m from road 0 and
      // 7 m from road 1 (raw distances differ by 4 m, under the 5 m
      // penalty), so staying on the already-snapped road 1 wins.
      final roadLines = [
        [const Pt(0, 0), const Pt(100, 0)], // road 0, y = 0
        [const Pt(0, 10), const Pt(100, 10)], // road 1, y = 10
      ];
      final result = snapToRoad(roadLines, const Pt(50, 3), lastLine: 1);

      expect(result, isNotNull);
      expect(result!.lineIndex, 1);
    });

    test(
      'switches roads when another one is clearly closer (beyond the penalty)',
      () {
        // Point is 9 m from road 0 (the current road) and 1 m from road 1;
        // the 8 m raw-distance gap exceeds the 5 m penalty, so it switches.
        final roadLines = [
          [const Pt(0, 0), const Pt(100, 0)], // road 0, y = 0
          [const Pt(0, 10), const Pt(100, 10)], // road 1, y = 10
        ];
        final result = snapToRoad(roadLines, const Pt(50, 9), lastLine: 0);

        expect(result, isNotNull);
        expect(result!.lineIndex, 1);
      },
    );
  });
}
