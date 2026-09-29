import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/game/geo.dart';
import 'package:walkman/game/ghosts.dart';
import 'package:walkman/game/graph.dart';

void main() {
  // A straight line of nodes 10m apart: 0 - 1 - 2 - 3 - 4 - 5.
  RoadGraph lineGraph() {
    final nodes = [for (int i = 0; i <= 5; i++) Pt(i * 10.0, 0)];
    final adj = <List<int>>[];
    for (int i = 0; i <= 5; i++) {
      final nb = <int>[];
      if (i > 0) nb.add(i - 1);
      if (i < 5) nb.add(i + 1);
      adj.add(nb);
    }
    return RoadGraph(nodes, adj);
  }

  test('ghost steps toward the player along the graph each tick', () {
    final graph = lineGraph();
    final rng = math.Random(7);
    final ghost = GhostState(at: 5, xy: graph.nodes[5]);
    const playerNode = 0;
    final playerXy = graph.nodes[playerNode];

    var lastDistance = ghost.xy.distanceTo(playerXy);
    for (int tick = 0; tick < 60; tick++) {
      final hops = bfs(graph, playerNode);
      tickGhost(
        graph: graph,
        g: ghost,
        playerXy: playerXy,
        playerNode: nearestNode(graph, playerXy),
        hops: hops,
        scared: false,
        rng: rng,
      );
      final d = ghost.xy.distanceTo(playerXy);
      expect(d, lessThanOrEqualTo(lastDistance + 1e-9));
      lastDistance = d;
    }
    expect(lastDistance, lessThan(1));
  });

  test('scared ghost moves away from the player', () {
    final graph = lineGraph();
    final rng = math.Random(3);
    final ghost = GhostState(at: 2, xy: graph.nodes[2]);
    const playerNode = 2;
    final playerXy = graph.nodes[playerNode];
    final hops = bfs(graph, playerNode);

    // Force the ghost off the player's node first so its "scared" choice is
    // a real neighbor-ranking decision, not the step-straight-at-player case.
    tickGhost(
      graph: graph,
      g: ghost,
      playerXy: playerXy,
      playerNode: playerNode,
      hops: hops,
      scared: true,
      rng: rng,
    );
    final distAfterFirstTick = ghost.xy.distanceTo(playerXy);
    expect(distAfterFirstTick, greaterThan(0));
  });

  test('ghost catch detection uses catchRadius', () {
    final ghost = GhostState(at: 0, xy: const Pt(0.5, 0));
    expect(ghostCaughtPlayer(ghost, const Pt(0, 0)), isTrue);
    final farGhost = GhostState(at: 0, xy: const Pt(50, 0));
    expect(ghostCaughtPlayer(farGhost, const Pt(0, 0)), isFalse);
  });

  test('pickGhostHome only considers reachable nodes', () {
    final graph = lineGraph();
    // Node 5 unreachable in this BFS view.
    final reach = [0, 1, 2, 3, 4, -1];
    final home = pickGhostHome(graph, reach, const Pt(1000, 1000));
    expect(home, 4); // nearest reachable node to a far-away spot
  });
}
