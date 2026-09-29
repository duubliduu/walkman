import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// A flat XY point in meters, relative to some origin lat/lng.
class Pt {
  final double x;
  final double y;
  const Pt(this.x, this.y);

  double get length => math.sqrt(x * x + y * y);

  double distanceTo(Pt other) {
    final dx = x - other.x, dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) => other is Pt && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => 'Pt($x, $y)';
}

const double _metersPerDegLat = 111320;

/// Converts a lat/lng to flat XY meters relative to [origin].
Pt toXY(LatLng origin, LatLng ll) {
  final x =
      (ll.longitude - origin.longitude) *
      _metersPerDegLat *
      math.cos(origin.latitude * math.pi / 180);
  final y = (ll.latitude - origin.latitude) * _metersPerDegLat;
  return Pt(x, y);
}

/// Offsets [origin] by [dx]/[dy] meters, returning a new LatLng.
LatLng offsetLatLng(LatLng origin, double dx, double dy) {
  return LatLng(
    origin.latitude + dy / _metersPerDegLat,
    origin.longitude +
        dx / (_metersPerDegLat * math.cos(origin.latitude * math.pi / 180)),
  );
}

final Distance _distance = const Distance();

/// Great-circle distance in meters, matching Leaflet's map.distance.
double llDistance(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);
