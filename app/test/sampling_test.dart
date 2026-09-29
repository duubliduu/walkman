import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/game/geo.dart';
import 'package:walkman/game/sampling.dart';

void main() {
  group('sampleWay', () {
    test(
      'samples a straight line every `spacing` meters plus the endpoint',
      () {
        final chain = sampleWay([const Pt(0, 0), const Pt(100, 0)], 25);

        expect(chain.length, 5);
        expect(chain[0], const Pt(0, 0));
        expect(chain[1].x, closeTo(25, 1e-9));
        expect(chain[2].x, closeTo(50, 1e-9));
        expect(chain[3].x, closeTo(75, 1e-9));
        expect(chain.last, const Pt(100, 0)); // end vertex always included
      },
    );

    test('carries leftover distance across multiple segments', () {
      // Two segments of 15m each = 30m total; spacing 25 should place one
      // point at t=25 (10m into the second segment) plus the end vertex.
      final chain = sampleWay([
        const Pt(0, 0),
        const Pt(15, 0),
        const Pt(30, 0),
      ], 25);

      expect(chain.length, 3); // start(0,0) sample, t=25 sample, end vertex
      expect(chain[0], const Pt(0, 0));
      expect(chain[1].x, closeTo(25, 1e-9));
      expect(chain.last, const Pt(30, 0));
    });

    test('does not sample beyond a short segment other than its endpoint', () {
      final chain = sampleWay([const Pt(0, 0), const Pt(10, 0)], 25);
      expect(chain, [const Pt(0, 0), const Pt(10, 0)]);
    });
  });

  group('gridChains', () {
    test('covers the requested radius with single-point chains', () {
      final chains = gridChains(radius: 50, spacing: 25);
      // -50..50 step 25 => 5 values per axis => 25 cells.
      expect(chains.length, 25);
      for (final c in chains) {
        expect(c.length, 1);
        expect(c.single.x.abs() <= 50, isTrue);
        expect(c.single.y.abs() <= 50, isTrue);
      }
    });
  });
}
