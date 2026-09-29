import 'dart:math' as math;

import 'constants.dart';
import 'geo.dart';

/// Samples a polyline [geometry] (already in flat XY meters) into a chain of
/// points every [spacing] meters, plus the final vertex. Mirrors the
/// `roadChains` sampling loop in index.html.
List<Pt> sampleWay(List<Pt> geometry, double spacing) {
  final chain = <Pt>[];
  if (geometry.isEmpty) return chain;
  double carry = 0;
  for (int i = 1; i < geometry.length; i++) {
    final p0 = geometry[i - 1], p1 = geometry[i];
    final len = math.sqrt(math.pow(p1.x - p0.x, 2) + math.pow(p1.y - p0.y, 2));
    if (len == 0) continue;
    for (double t = carry; t < len; t += spacing) {
      chain.add(
        Pt(p0.x + (p1.x - p0.x) * t / len, p0.y + (p1.y - p0.y) * t / len),
      );
    }
    carry = (carry - len) % spacing;
    if (carry < 0) carry += spacing;
  }
  chain.add(geometry.last);
  return chain;
}

/// Grid fallback chains: one single-point "chain" per grid cell, spaced
/// [spacing] meters apart, covering [radius] meters in every direction.
List<List<Pt>> gridChains({
  double radius = fieldRadius,
  double spacing = dotSpacing,
}) {
  final chains = <List<Pt>>[];
  for (double x = -radius; x <= radius; x += spacing) {
    for (double y = -radius; y <= radius; y += spacing) {
      chains.add([Pt(x, y)]);
    }
  }
  return chains;
}
