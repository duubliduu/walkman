import 'constants.dart';
import 'geo.dart';

/// A road graph: nodes are dot positions (flat XY meters), edges connect
/// consecutive points along a road plus nodes closer than the build's
/// proximity threshold.
class RoadGraph {
  final List<Pt> nodes;
  final List<List<int>> adj;
  const RoadGraph(this.nodes, this.adj);
}

/// Builds a [RoadGraph] from a set of polyline [chains] (already sampled),
/// linking nodes within [prox] meters of each other. Nodes further than
/// [clipRadius] from the origin are dropped. Nodes within [mergeDistance] of
/// an existing node are merged into it (dedupe).
RoadGraph buildGraph(
  List<List<Pt>> chains,
  double prox, {
  double clipRadius = fieldRadius,
  double mergeDistance = nodeMergeDistance,
}) {
  final nodes = <Pt>[];
  final adj = <Set<int>>[];

  void link(int a, int b) {
    if (a != b) {
      adj[a].add(b);
      adj[b].add(a);
    }
  }

  int nodeFor(Pt p) {
    if (p.length > clipRadius) return -1;
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].distanceTo(p) < mergeDistance) return i;
    }
    nodes.add(p);
    adj.add(<int>{});
    return nodes.length - 1;
  }

  for (final chain in chains) {
    int prev = -1;
    for (final p in chain) {
      final i = nodeFor(p);
      if (i >= 0 && prev >= 0) link(i, prev);
      prev = i;
    }
  }

  for (int a = 0; a < nodes.length; a++) {
    for (int b = a + 1; b < nodes.length; b++) {
      if (nodes[a].distanceTo(nodes[b]) < prox) link(a, b);
    }
  }

  return RoadGraph(nodes, [for (final s in adj) s.toList()]);
}

/// Hop count from [from] to every node. -1 means unreachable.
List<int> bfs(RoadGraph graph, int from) {
  final d = List<int>.filled(graph.nodes.length, -1);
  if (from < 0 || from >= graph.nodes.length) return d;
  d[from] = 0;
  final queue = <int>[from];
  for (int i = 0; i < queue.length; i++) {
    for (final n in graph.adj[queue[i]]) {
      if (d[n] == -1) {
        d[n] = d[queue[i]] + 1;
        queue.add(n);
      }
    }
  }
  return d;
}

/// Index of the node nearest to [xy].
int nearestNode(RoadGraph graph, Pt xy) {
  int best = 0;
  for (int i = 1; i < graph.nodes.length; i++) {
    if (graph.nodes[i].distanceTo(xy) < graph.nodes[best].distanceTo(xy)) {
      best = i;
    }
  }
  return best;
}

/// Picks the farthest-from-origin node in each of the 4 quadrants as a power
/// pellet location.
Set<int> powerPelletIndices(List<Pt> nodes) {
  final result = <int>{};
  for (int qd = 0; qd < 4; qd++) {
    int best = -1;
    for (int i = 0; i < nodes.length; i++) {
      final p = nodes[i];
      final qx = (p.x >= 0) == ((qd & 1) != 0);
      final qy = (p.y >= 0) == ((qd & 2) != 0);
      if (qx && qy && (best < 0 || p.length > nodes[best].length)) best = i;
    }
    if (best >= 0) result.add(best);
  }
  return result;
}
