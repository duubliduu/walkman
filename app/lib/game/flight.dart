import 'package:latlong2/latlong.dart';

import 'constants.dart';
import 'geo.dart';

/// Tracks recent GPS fixes and computes km/h over the last
/// [speedWindowMs] window, same as `trackSpeed` in index.html.
class SpeedTracker {
  final List<({LatLng ll, int t})> _fixes = [];

  /// Adds a fix (lat/lng + epoch ms) and returns the current speed in km/h.
  double addFix(LatLng ll, int tMs) {
    _fixes.add((ll: ll, t: tMs));
    while (_fixes.length > 2 && tMs - _fixes[1].t >= speedWindowMs) {
      _fixes.removeAt(0);
    }
    final dtSec = (tMs - _fixes.first.t) / 1000;
    if (dtSec >= 3) {
      final meters = llDistance(_fixes.first.ll, ll);
      return meters / dtSec * 3.6;
    }
    return 0;
  }
}

/// Tracks whether the user is "on foot": true if a step event or a
/// "walking" pedestrian status was seen within the last [onFootWindowMs].
class OnFootTracker {
  int? _lastEventMs;

  void recordEvent(int nowMs) => _lastEventMs = nowMs;

  bool isOnFoot(int nowMs) {
    final last = _lastEventMs;
    return last != null && nowMs - last <= onFootWindowMs;
  }
}

/// Pause/resume state machine for "flight mode" (moving too fast to be
/// walking, e.g. in a car).
///
/// With a pedometer available:
///  - enter flight if (speed > 3 km/h AND not on foot) OR speed > 25 km/h
///  - resume walking if (on foot AND speed < 22 km/h) OR speed < 2 km/h
///
/// Without a pedometer, falls back to the original speed-only rule from
/// index.html: enter > 15 km/h, resume < 13 km/h.
class FlightStateMachine {
  bool flying = false;

  bool update({
    required double speedKmh,
    required bool onFoot,
    required bool pedometerAvailable,
  }) {
    if (pedometerAvailable) {
      if (!flying) {
        if ((speedKmh > flightEnterSpeedKmh && !onFoot) ||
            speedKmh > flightForceEnterSpeedKmh) {
          flying = true;
        }
      } else {
        if ((onFoot && speedKmh < flightResumeOnFootSpeedKmh) ||
            speedKmh < flightResumeSlowSpeedKmh) {
          flying = false;
        }
      }
    } else {
      if (!flying && speedKmh > flightKmhFallback) {
        flying = true;
      } else if (flying && speedKmh < resumeKmhFallback) {
        flying = false;
      }
    }
    return flying;
  }
}
