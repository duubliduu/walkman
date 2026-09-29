import 'constants.dart';
import 'geo.dart';

/// Result of snapping a point onto a road polyline.
class SnapResult {
  /// The snapped point, in the same flat XY meters as the input.
  final Pt xy;

  /// Index into the polyline list of the road that was snapped to.
  final int lineIndex;

  const SnapResult(this.xy, this.lineIndex);

  @override
  bool operator ==(Object other) =>
      other is SnapResult && other.xy == xy && other.lineIndex == lineIndex;
  @override
  int get hashCode => Object.hash(xy, lineIndex);
  @override
  String toString() => 'SnapResult($xy, line $lineIndex)';
}

/// Projects [xy] onto the nearest point of any segment across [roadLines]
/// (each a polyline of consecutive points, in flat XY meters).
///
/// Staying on [lastLine] (the road last snapped to) is preferred: any other
/// road is penalized by [penalty] meters, so the player doesn't hop between
/// parallel roads on every GPS jitter. Returns null ("off road") if the best
/// candidate is farther than [maxDistance] meters away.
///
/// Mirrors `snapToRoad` in index.html.
SnapResult? snapToRoad(
  List<List<Pt>> roadLines,
  Pt xy, {
  int lastLine = -1,
  double maxDistance = snapMax,
  double penalty = switchRoadPenalty,
}) {
  SnapResult? best;
  double bestDist = double.infinity;
  double bestRank = double.infinity;

  for (int li = 0; li < roadLines.length; li++) {
    final line = roadLines[li];
    for (int i = 1; i < line.length; i++) {
      final a = line[i - 1];
      final b = line[i];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final lenSq = dx * dx + dy * dy;
      double t = lenSq == 0
          ? 0
          : ((xy.x - a.x) * dx + (xy.y - a.y) * dy) / lenSq;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
      final p = Pt(a.x + dx * t, a.y + dy * t);
      final d = p.distanceTo(xy);
      final rank = d + (li == lastLine ? 0 : penalty);
      if (rank < bestRank) {
        bestRank = rank;
        bestDist = d;
        best = SnapResult(p, li);
      }
    }
  }

  if (best == null || bestDist > maxDistance) return null;
  return best;
}
