import 'dart:math' as math;

import 'constants.dart';
import 'geo.dart';
import 'graph.dart';

/// Mutable ghost position/state, tracked in graph-node space.
class GhostState {
  int at;
  int to; // -1 means "not currently travelling to a node"
  Pt xy;
  GhostState({required this.at, this.to = -1, required this.xy});

  void sendHome(RoadGraph graph) {
    to = -1;
    xy = graph.nodes[at];
  }
}

/// Picks a home node for a ghost: the reachable node nearest [spot].
/// [reach] is the BFS distance array from the player's start node; -1 means
/// unreachable and such nodes are excluded.
int pickGhostHome(RoadGraph graph, List<int> reach, Pt spot) {
  int best = -1;
  for (int i = 0; i < graph.nodes.length; i++) {
    if (reach[i] == -1) continue;
    if (best < 0 ||
        graph.nodes[i].distanceTo(spot) < graph.nodes[best].distanceTo(spot)) {
      best = i;
    }
  }
  return best;
}

class _StepResult {
  final Pt xy;
  final double remaining;
  _StepResult(this.xy, this.remaining);
}

_StepResult _stepTo(Pt from, Pt target, double budget) {
  final d = from.distanceTo(target);
  if (d <= budget) return _StepResult(target, budget - d);
  final t = d == 0 ? 0.0 : budget / d;
  return _StepResult(
    Pt(from.x + (target.x - from.x) * t, from.y + (target.y - from.y) * t),
    0,
  );
}

/// Advances one ghost by one tick (1 second worth of movement at
/// [speed] m/s, halved when [scared]). Mirrors `tick()`'s per-ghost loop in
/// index.html: walks the road graph towards (or, when scared, away from) the
/// player, and steps straight at the player when standing on their node.
void tickGhost({
  required RoadGraph graph,
  required GhostState g,
  required Pt playerXy,
  required int playerNode,
  required List<int> hops,
  required bool scared,
  required math.Random rng,
  double speed = ghostSpeed,
}) {
  double budget = speed * (scared ? 0.5 : 1);
  for (int guard = 0; budget > 0 && guard < 10; guard++) {
    if (g.to < 0) {
      if (!scared && g.at == playerNode) {
        final r = _stepTo(g.xy, playerXy, budget);
        g.xy = r.xy;
        break;
      }
      final nb = graph.adj[g.at];
      if (nb.isEmpty) break;
      double rank(int n) => hops[n] == -1
          ? rng.nextDouble() * 1e6
          : hops[n] + rng.nextDouble() * 0.5;
      int bestN = nb.first;
      double bestRank = rank(bestN);
      for (final n in nb.skip(1)) {
        final r = rank(n);
        final better = scared ? r > bestRank : r < bestRank;
        if (better) {
          bestN = n;
          bestRank = r;
        }
      }
      g.to = bestN;
    }
    final target = graph.nodes[g.to];
    final r = _stepTo(g.xy, target, budget);
    g.xy = r.xy;
    budget = r.remaining;
    if (budget > 0 || g.xy.distanceTo(target) < 0.01) {
      g.at = g.to;
      g.to = -1;
    }
  }
}

/// True if the ghost is within catch range of the player.
bool ghostCaughtPlayer(GhostState g, Pt playerXy) =>
    g.xy.distanceTo(playerXy) < catchRadius;
