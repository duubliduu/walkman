import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'constants.dart';
import 'geo.dart';
import 'sampling.dart';

/// Overpass mirrors to try in order, matching index.html.
const List<String> overpassUrls = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];

const overpassUserAgent = 'walkman/1.0 (com.duubliduu.walkman)';

/// Completes with the first future that succeeds; fails only if all fail.
Future<T> _firstSuccess<T>(Iterable<Future<T>> futures) {
  final done = Completer<T>();
  final list = futures.toList();
  var pending = list.length;
  for (final f in list) {
    f.then(
      (v) {
        if (!done.isCompleted) done.complete(v);
      },
      onError: (Object e) {
        if (--pending == 0 && !done.isCompleted) done.completeError(e);
      },
    );
  }
  return done.future;
}

const _highwayTypes =
    'footway|path|pedestrian|residential|living_street|service|unclassified|tertiary|secondary|primary|cycleway|steps|track';

/// Builds the Overpass QL query for walkable ways around [lat]/[lng].
String overpassQuery(double lat, double lng, {double radius = fieldRadius}) {
  return '[out:json][timeout:15];way["highway"~"^($_highwayTypes)\$"](around:$radius,$lat,$lng);out geom;';
}

/// Fetches walkable ways around [origin] from the first Overpass mirror that
/// responds.
///
/// [chains] samples each way into a chain of points every [dotSpacing]
/// meters (plus its end vertex), for building the dot graph. [rawLines]
/// holds each way's full, unsampled, unclipped geometry, for snapping the
/// player to the nearest road. Both are in flat XY meters relative to
/// [origin]. Throws if every mirror fails.
Future<({List<List<Pt>> chains, List<List<Pt>> rawLines})> fetchRoadChains(
  LatLng origin, {
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  final q = overpassQuery(origin.latitude, origin.longitude);
  // Query every mirror at once and take the first good answer: public
  // Overpass servers are often slow (20 s+), overloaded or rate-limited.
  // overpass-api.de rejects Dart's default User-Agent with 406, so send ours.
  Future<Map<String, dynamic>> ask(String url) async {
    final res = await c
        .post(
          Uri.parse(url),
          headers: {'User-Agent': overpassUserAgent},
          body: {'data': q},
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw Exception('$url: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Map<String, dynamic>? data;
  try {
    data = await _firstSuccess(overpassUrls.map(ask));
  } catch (_) {
    data = null;
  } finally {
    if (client == null) c.close();
  }
  if (data == null) throw Exception('no overpass server reachable');

  final elements = (data['elements'] as List?) ?? const [];
  final chains = <List<Pt>>[];
  final rawLines = <List<Pt>>[];
  for (final el in elements) {
    final geometry = (el['geometry'] as List?) ?? const [];
    if (geometry.isEmpty) continue;
    final xy = <Pt>[
      for (final v in geometry)
        toXY(
          origin,
          LatLng((v['lat'] as num).toDouble(), (v['lon'] as num).toDouble()),
        ),
    ];
    rawLines.add(xy);
    chains.add(sampleWay(xy, dotSpacing));
  }
  return (chains: chains, rawLines: rawLines);
}
