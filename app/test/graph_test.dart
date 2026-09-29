import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/game/geo.dart';
import 'package:walkman/game/graph.dart';

void main() {
  group('buildGraph', () {
    test('dedupes nodes within mergeDistance', () {
      // Two chains that both pass through (almost) the same point; the
      // intra-chain spacing (30m) is kept above mergeDistance so only the
      // shared boundary point collapses.
      final chains = [
        [const Pt(0, 0), const Pt(30, 0)],
        [const Pt(30.0001, 0), const Pt(60, 0)],
      ];
      final graph = buildGraph(chains, 1, clipRadius: 1000, mergeDistance: 15);

      // (0,0), merged (30,0)/(30.0001,0), (60,0) => 3 nodes, not 4.
      expect(graph.nodes.length, 3);
    });

    test('links nodes closer than `prox` even across separate chains', () {
      // Two perpendicular, densely-sampled chains that cross near the middle
      // without sharing an exact sampled point (offset by 0.5m).
      final horizontal = [for (double x = -20; x <= 20; x += 10) Pt(x, 0.5)];
      final vertical = [for (double y = -20; y <= 20; y += 10) Pt(0, y)];
      final graph = buildGraph(
        [horizontal, vertical],
        5,
        clipRadius: 1000,
        mergeDistance: 0.1,
      );

      int nearest(double x, double y) {
        int best = 0;
        for (var i = 1; i < graph.nodes.length; i++) {
          if (graph.nodes[i].distanceTo(Pt(x, y)) <
              graph.nodes[best].distanceTo(Pt(x, y))) {
            best = i;
          }
        }
        return best;
      }

      final a = nearest(0, 0.5); // on the horizontal chain
      final b = nearest(0, 0); // on the vertical chain
      expect(a, isNot(b));
      expect(graph.adj[a].contains(b), isTrue);
    });

    test('drops nodes beyond clipRadius', () {
      final chains = [
        [const Pt(0, 0), const Pt(300, 0)],
      ];
      final graph = buildGraph(chains, 30, clipRadius: 200);
      for (final n in graph.nodes) {
        expect(n.length <= 200, isTrue);
      }
    });
  });

  group('bfs', () {
    test('counts hops along a simple path graph', () {
      // 0 - 1 - 2 - 3
      final nodes = [
        const Pt(0, 0),
        const Pt(10, 0),
        const Pt(20, 0),
        const Pt(30, 0),
      ];
      final graph = RoadGraph(nodes, [
        [1],
        [0, 2],
        [1, 3],
        [2],
      ]);

      final hops = bfs(graph, 0);
      expect(hops, [0, 1, 2, 3]);
    });

    test('marks unreachable nodes as -1', () {
      final nodes = [const Pt(0, 0), const Pt(10, 0), const Pt(1000, 1000)];
      final graph = RoadGraph(nodes, [
        [1],
        [0],
        [],
      ]);
      final hops = bfs(graph, 0);
      expect(hops, [0, 1, -1]);
    });
  });

  group('nearestNode', () {
    test('finds the closest node to a point', () {
      final graph = RoadGraph(
        [const Pt(0, 0), const Pt(10, 0), const Pt(100, 0)],
        [[], [], []],
      );
      expect(nearestNode(graph, const Pt(9, 0)), 1);
    });
  });

  group('powerPelletIndices', () {
    test('picks the farthest node in each quadrant', () {
      final nodes = [
        const Pt(5, 5), // Q0 (x>=0,y>=0), near
        const Pt(50, 50), // Q0, far -> pellet
        const Pt(-50, 5), // Q1 (x<0,y>=0) -> pellet
        const Pt(5, -50), // Q2 (x>=0,y<0) -> pellet
        const Pt(-50, -50), // Q3 (x<0,y<0) -> pellet
      ];
      final pellets = powerPelletIndices(nodes);
      expect(pellets, {1, 2, 3, 4});
    });
  });
}
