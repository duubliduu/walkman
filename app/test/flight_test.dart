import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:walkman/game/flight.dart';

void main() {
  group('FlightStateMachine with pedometer available', () {
    test('does not enter flight while walking under the speed cap', () {
      final sm = FlightStateMachine();
      final flying = sm.update(
        speedKmh: 5,
        onFoot: true,
        pedometerAvailable: true,
      );
      expect(flying, isFalse);
    });

    test('enters flight above 3 km/h when not on foot', () {
      final sm = FlightStateMachine();
      final flying = sm.update(
        speedKmh: 4,
        onFoot: false,
        pedometerAvailable: true,
      );
      expect(flying, isTrue);
    });

    test('forces flight above 25 km/h even if flagged as on foot', () {
      final sm = FlightStateMachine();
      final flying = sm.update(
        speedKmh: 26,
        onFoot: true,
        pedometerAvailable: true,
      );
      expect(flying, isTrue);
    });

    test('resumes when on foot and under 22 km/h', () {
      final sm = FlightStateMachine();
      sm.update(speedKmh: 30, onFoot: false, pedometerAvailable: true);
      expect(sm.flying, isTrue);
      final flying = sm.update(
        speedKmh: 20,
        onFoot: true,
        pedometerAvailable: true,
      );
      expect(flying, isFalse);
    });

    test(
      'resumes when speed drops under 2 km/h regardless of on-foot flag',
      () {
        final sm = FlightStateMachine();
        sm.update(speedKmh: 30, onFoot: false, pedometerAvailable: true);
        final flying = sm.update(
          speedKmh: 1,
          onFoot: false,
          pedometerAvailable: true,
        );
        expect(flying, isFalse);
      },
    );

    test('stays flying when on foot but still above 22 km/h', () {
      final sm = FlightStateMachine();
      sm.update(speedKmh: 30, onFoot: false, pedometerAvailable: true);
      final flying = sm.update(
        speedKmh: 23,
        onFoot: true,
        pedometerAvailable: true,
      );
      expect(flying, isTrue);
    });
  });

  group(
    'FlightStateMachine falls back to speed-only rule without a pedometer',
    () {
      test('enters flight only above 15 km/h', () {
        final sm = FlightStateMachine();
        expect(
          sm.update(speedKmh: 10, onFoot: false, pedometerAvailable: false),
          isFalse,
        );
        expect(
          sm.update(speedKmh: 16, onFoot: false, pedometerAvailable: false),
          isTrue,
        );
      });

      test('resumes only below 13 km/h', () {
        final sm = FlightStateMachine();
        sm.update(speedKmh: 20, onFoot: false, pedometerAvailable: false);
        expect(
          sm.update(speedKmh: 14, onFoot: true, pedometerAvailable: false),
          isTrue,
        );
        expect(
          sm.update(speedKmh: 12, onFoot: true, pedometerAvailable: false),
          isFalse,
        );
      });
    },
  );

  group('OnFootTracker', () {
    test('is on foot only within the freshness window', () {
      final tracker = OnFootTracker();
      expect(tracker.isOnFoot(0), isFalse);
      tracker.recordEvent(1000);
      expect(tracker.isOnFoot(1000), isTrue);
      expect(tracker.isOnFoot(1000 + 10000), isTrue);
      expect(tracker.isOnFoot(1000 + 10001), isFalse);
    });
  });

  group('SpeedTracker', () {
    test('reports 0 until the averaging window has enough history', () {
      final tracker = SpeedTracker();
      final a = LatLng(60.170, 24.940);
      expect(tracker.addFix(a, 0), 0);
    });

    test('computes km/h from distance over the last window', () {
      final tracker = SpeedTracker();
      final a = LatLng(60.170000, 24.940000);
      final b = LatLng(60.170000, 24.941000); // ~55.7m east at this latitude
      tracker.addFix(a, 0);
      final kmh = tracker.addFix(b, 10000); // 10s later
      expect(kmh, greaterThan(15));
      expect(kmh, lessThan(25));
    });
  });
}
