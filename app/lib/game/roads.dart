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

const _highwayTypes =
    'footway|path|pedestrian|residential|living_street|service|unclassified|tertiary|secondary|primary|cycleway|steps|track';

/// Builds the Overpass QL query for walkable ways around [lat]/[lng].
String overpassQuery(double lat, double lng, {double radius = fieldRadius}) {
  return '[out:json][timeout:15];way["highway"~"^($_highwayTypes)\$"](around:$radius,$lat,$lng);out geom;';
}

/// Fetches walkable ways around [origin] from the first Overpass mirror that
/// responds, and samples each way into a chain of points every
/// [dotSpacing] meters (plus its end vertex), in flat XY meters relative to
/// [origin]. Throws if every mirror fails.
Future<List<List<Pt>>> fetchRoadChains(
  LatLng origin, {
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  final q = overpassQuery(origin.latitude, origin.longitude);
  Map<String, dynamic>? data;
  try {
    for (final url in overpassUrls) {
      try {
        final res = await http
            .post(Uri.parse(url), body: {'data': q})
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          data = jsonDecode(res.body) as Map<String, dynamic>;
          break;
        }
      } catch (_) {
        // try next mirror
      }
    }
  } finally {
    if (client == null) c.close();
  }
  if (data == null) throw Exception('no overpass server reachable');

  final elements = (data['elements'] as List?) ?? const [];
  final chains = <List<Pt>>[];
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
    chains.add(sampleWay(xy, dotSpacing));
  }
  return chains;
}
