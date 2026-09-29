import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'game/constants.dart';
import 'game/flight.dart';
import 'game/geo.dart';
import 'game/ghosts.dart';
import 'game/graph.dart';
import 'game/roads.dart';
import 'game/sampling.dart';
import 'game/sound.dart';

class _Dot {
  final Pt xy;
  final bool power;
  _Dot(this.xy, this.power);
}

/// Owns all mutable game state and side effects (GPS, sensors, audio,
/// haptics, timers). UI reads it via [ChangeNotifier].
class GameController extends ChangeNotifier {
  // Public, UI-visible state.
  bool started = false;
  bool over = false;
  bool win = false;
  bool launched = false; // START pressed; hides the start screen
  bool showPad = false; // debug d-pad, shown when GPS is unavailable/denied
  bool flying = false;

  int score = 0;
  int lives = startLives;
  double walked = 0;
  double heading = 0; // radians, 0 = east
  String statusText = 'GPS: waiting';

  LatLng? origin;
  LatLng? pos;
  RoadGraph? graph;

  final ValueNotifier<bool> chomping = ValueNotifier<bool>(false);

  final List<_Dot> _dots = [];
  final List<GhostState> ghosts = [];

  DateTime? powerUntil;
  bool get scared => powerUntil != null && DateTime.now().isBefore(powerUntil!);

  // Internals.
  final math.Random _rng = math.Random();
  final GameSounds sounds = GameSounds();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SpeedTracker _speedTracker = SpeedTracker();
  final OnFootTracker _onFootTracker = OnFootTracker();
  final FlightStateMachine _flightSm = FlightStateMachine();
  bool _pedometerAvailable = true;
  bool _wakaFlip = false;
  bool _settingUp = false;
  Pt? _headingFrom;

  Timer? _ghostTicker;
  Timer? _chompTimer;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;

  /// Kicks off permissions, sensors and the GPS stream. Falls back to the
  /// on-screen d-pad if GPS is unavailable or denied.
  Future<void> start() async {
    launched = true;
    notifyListeners();
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // best-effort only
    }
    await _initPedometer();
    final gpsOk = await _initLocation();
    if (!gpsOk) {
      showPad = true;
    }
    notifyListeners();
  }

  Future<void> _initPedometer() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.activityRecognition.request();
        if (!status.isGranted) {
          _pedometerAvailable = false;
          return;
        }
      }
      _stepSub = Pedometer.stepCountStream.listen(
        (_) =>
            _onFootTracker.recordEvent(DateTime.now().millisecondsSinceEpoch),
        onError: (_) => _pedometerAvailable = false,
      );
      _statusSub = Pedometer.pedestrianStatusStream.listen((event) {
        if (event.status == 'walking') {
          _onFootTracker.recordEvent(DateTime.now().millisecondsSinceEpoch);
        }
      }, onError: (_) {});
    } catch (_) {
      _pedometerAvailable = false;
    }
  }

  Future<bool> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        statusText = 'GPS off: service disabled';
        return false;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        statusText = 'GPS off: permission denied';
        return false;
      }
      _posSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
            ),
          ).listen(
            _onPosition,
            onError: (Object e) {
              statusText = 'GPS off: $e';
              showPad = true;
              notifyListeners();
            },
          );
      return true;
    } catch (e) {
      statusText = 'GPS off: $e';
      return false;
    }
  }

  void _onPosition(Position p) {
    if (showPad) return; // sim mode disables GPS-driven moves
    if (started && p.accuracy >= 50) return;
    final ll = LatLng(p.latitude, p.longitude);
    if (started) {
      final tMs = p.timestamp.millisecondsSinceEpoch;
      final kmh = _speedTracker.addFix(ll, tMs);
      final onFoot = _onFootTracker.isOnFoot(
        DateTime.now().millisecondsSinceEpoch,
      );
      flying = _flightSm.update(
        speedKmh: kmh,
        onFoot: onFoot,
        pedometerAvailable: _pedometerAvailable,
      );
      statusText =
          'GPS ±${p.accuracy.round()} m · ${kmh.toStringAsFixed(1)} km/h'
          '${flying ? ' · flying' : (onFoot ? ' · walking' : '')}';
    }
    moveTo(ll);
  }

  /// Simulated movement from the debug d-pad, [dx]/[dy] in meters.
  void padMove(double dx, double dy) {
    final base = pos ?? const LatLng(60.17, 24.94);
    moveTo(offsetLatLng(base, dx, dy));
  }

  void moveTo(LatLng ll) {
    if (over) return;
    if (!started) {
      unawaited(_setup(ll));
      return;
    }
    if (flying) {
      chomping.value = false;
      pos = ll;
      _headingFrom = null;
      notifyListeners();
      return;
    }
    final o = origin!;
    final prevPos = pos;
    if (prevPos != null) walked += llDistance(prevPos, ll);

    final anchor = _headingFrom ?? toXY(o, prevPos ?? ll);
    _headingFrom ??= anchor;
    final xy1 = toXY(o, ll);
    if (anchor.distanceTo(xy1) >= 3) {
      heading = math.atan2(-(xy1.y - anchor.y), xy1.x - anchor.x);
      chomping.value = true;
      _chompTimer?.cancel();
      _chompTimer = Timer(
        const Duration(seconds: 3),
        () => chomping.value = false,
      );
      _headingFrom = xy1;
    }
    pos = ll;

    _dots.removeWhere((d) {
      final dll = offsetLatLng(o, d.xy.x, d.xy.y);
      if (llDistance(dll, pos!) > eatRadius) return false;
      score += d.power ? scorePower : scoreDot;
      if (d.power) {
        HapticFeedback.heavyImpact();
        unawaited(_playSound(sounds.power));
        powerUntil = DateTime.now().add(const Duration(milliseconds: powerMs));
      } else {
        HapticFeedback.lightImpact();
        unawaited(_playSound(_wakaSound()));
      }
      return true;
    });

    if (_dots.isEmpty) {
      _end(win: true);
      return;
    }
    notifyListeners();
  }

  Future<void> _setup(LatLng originLl) async {
    if (_settingUp) return;
    _settingUp = true;
    origin = originLl;
    statusText = 'Loading roads…';
    notifyListeners();

    try {
      final chains = await fetchRoadChains(originLl);
      final g = buildGraph(chains, roadLinkProximity);
      if (g.nodes.length < 10) throw Exception('too few roads');
      graph = g;
      statusText = '${g.nodes.length} dots on roads';
    } catch (_) {
      graph = buildGraph(gridChains(), gridLinkProximity);
      statusText = 'Roads failed, grid mode';
    }

    final nodes = graph!.nodes;
    final power = powerPelletIndices(nodes);
    _dots.clear();
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].length >= eatRadius) {
        _dots.add(_Dot(nodes[i], power.contains(i)));
      }
    }

    final reach = bfs(graph!, nearestNode(graph!, const Pt(0, 0)));
    ghosts.clear();
    for (int i = 0; i < ghostColors.length; i++) {
      final a = i * math.pi / 2 + math.pi / 4;
      final spot = Pt(
        math.cos(a) * fieldRadius * 0.9,
        math.sin(a) * fieldRadius * 0.9,
      );
      final home = pickGhostHome(graph!, reach, spot);
      ghosts.add(GhostState(at: home, xy: graph!.nodes[home]));
    }

    pos = originLl;
    started = true;
    _settingUp = false;
    _ghostTicker?.cancel();
    _ghostTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickGhosts(),
    );
    notifyListeners();
  }

  void _tickGhosts() {
    if (over || flying || graph == null || pos == null) return;
    final o = origin!;
    final isScared = scared;
    final me = toXY(o, pos!);
    final meNode = nearestNode(graph!, me);
    final hops = bfs(graph!, meNode);

    for (final g in ghosts) {
      if (over) break;
      tickGhost(
        graph: graph!,
        g: g,
        playerXy: me,
        playerNode: meNode,
        hops: hops,
        scared: isScared,
        rng: _rng,
      );
      if (ghostCaughtPlayer(g, me)) {
        if (isScared) {
          score += scoreGhost;
          g.sendHome(graph!);
        } else {
          lives -= 1;
          if (lives <= 0) {
            _end(win: false);
            break;
          }
          for (final gg in ghosts) {
            gg.sendHome(graph!);
          }
        }
        HapticFeedback.heavyImpact();
        if (!isScared) unawaited(_playSound(sounds.caught));
      }
    }
    notifyListeners();
  }

  Uint8List _wakaSound() {
    _wakaFlip = !_wakaFlip;
    return _wakaFlip ? sounds.wakaA : sounds.wakaB;
  }

  Future<void> _playSound(Uint8List bytes) async {
    try {
      await _audioPlayer.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Audio is best-effort; ignore playback failures.
    }
  }

  void _end({required bool win}) {
    over = true;
    this.win = win;
    _ghostTicker?.cancel();
    notifyListeners();
  }

  /// Resets to the pre-start state so the UI can show the start screen again
  /// (equivalent to index.html's full page reload on "AGAIN").
  void reset() {
    _ghostTicker?.cancel();
    _chompTimer?.cancel();
    _posSub?.cancel();
    _posSub = null;
    _stepSub?.cancel();
    _stepSub = null;
    _statusSub?.cancel();
    _statusSub = null;
    started = false;
    over = false;
    win = false;
    launched = false;
    showPad = false;
    flying = false;
    score = 0;
    lives = startLives;
    walked = 0;
    heading = 0;
    powerUntil = null;
    _dots.clear();
    ghosts.clear();
    graph = null;
    origin = null;
    pos = null;
    _headingFrom = null;
    chomping.value = false;
    statusText = 'GPS: waiting';
    notifyListeners();
  }

  List<({LatLng ll, bool power})> get renderDots {
    final o = origin;
    if (o == null) return const [];
    return [
      for (final d in _dots)
        (ll: offsetLatLng(o, d.xy.x, d.xy.y), power: d.power),
    ];
  }

  List<({LatLng ll, Color color})> get renderGhosts {
    final o = origin;
    if (o == null) return const [];
    final isScared = scared;
    return [
      for (int i = 0; i < ghosts.length; i++)
        (
          ll: offsetLatLng(o, ghosts[i].xy.x, ghosts[i].xy.y),
          color: isScared ? const Color(0xff2222ff) : Color(ghostColors[i]),
        ),
    ];
  }

  @override
  void dispose() {
    _ghostTicker?.cancel();
    _chompTimer?.cancel();
    _posSub?.cancel();
    _stepSub?.cancel();
    _statusSub?.cancel();
    _audioPlayer.dispose();
    chomping.dispose();
    super.dispose();
  }
}
