import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'game_controller.dart';
import 'pacman_painter.dart';

void main() {
  runApp(const WalkmanApp());
}

class WalkmanApp extends StatelessWidget {
  const WalkmanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walkman',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const GameScreen(),
    );
  }
}

const LatLng _defaultCenter = LatLng(60.17, 24.94);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameController controller;
  late final AnimationController mouthAnim;
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    controller = GameController();
    controller.addListener(_onControllerChanged);
    mouthAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..repeat(reverse: true);
  }

  void _onControllerChanged() {
    final p = controller.pos;
    if (p != null) {
      final zoom = controller.started ? 18.0 : mapController.camera.zoom;
      try {
        mapController.move(p, zoom);
      } catch (_) {
        // Map not laid out yet; ignore.
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    mouthAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          if (controller.launched) _buildHud(),
          if (controller.launched && controller.flying) _buildFlightBanner(),
          if (controller.launched) _buildStatus(),
          if (controller.showPad) _DPad(onMove: controller.padMove),
          if (!controller.launched || controller.over) _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: controller.pos ?? _defaultCenter,
        initialZoom: 17,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.duubliduu.walkman',
          tileBuilder: darkModeTileBuilder,
        ),
        CircleLayer(
          circles: [
            for (final d in controller.renderDots)
              CircleMarker(
                point: d.ll,
                radius: d.power ? 8 : 4,
                color: const Color(0xffffccbb),
              ),
          ],
        ),
        CircleLayer(
          circles: [
            for (final g in controller.renderGhosts)
              CircleMarker(
                point: g.ll,
                radius: 9,
                color: g.color,
                borderStrokeWidth: 2,
                borderColor: g.color,
              ),
          ],
        ),
        if (controller.pos != null)
          MarkerLayer(
            markers: [
              Marker(
                point: controller.pos!,
                width: 28,
                height: 28,
                child: AnimatedBuilder(
                  animation: Listenable.merge([controller.chomping, mouthAnim]),
                  builder: (context, _) => CustomPaint(
                    painter: PacmanPainter(
                      headingRadians: controller.heading,
                      mouthOpen: controller.chomping.value
                          ? mouthAnim.value
                          : 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SCORE ${controller.score}', style: _hudStyle),
            Text(
              '${controller.walked.round()} m${controller.scared ? ' ⚡' : ''}',
              style: _hudStyle,
            ),
            Text('♥' * controller.lives.clamp(0, 99), style: _hudStyle),
          ],
        ),
      ),
    );
  }

  static const _hudStyle = TextStyle(
    color: Color(0xffffff00),
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
    fontSize: 16,
  );

  Widget _buildFlightBanner() {
    return Positioned(
      left: 16,
      right: 16,
      top: 56,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xff00ffff),
          child: const Text(
            'FLIGHT MODE — PAUSED',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    return Positioned(
      left: 16,
      bottom: 24,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: const Color(0xb3000000),
          child: Text(controller.statusText, style: _statusStyle),
        ),
      ),
    );
  }

  static const _statusStyle = TextStyle(
    color: Color(0xffffff00),
    fontFamily: 'monospace',
    fontSize: 12,
  );

  Widget _buildOverlay() {
    if (controller.over) {
      return _MessageOverlay(
        title: controller.win ? 'YOU WIN!' : 'GAME OVER',
        subtitle:
            'SCORE ${controller.score}\n${controller.walked.round()} m walked',
        buttonLabel: 'AGAIN',
        onPressed: () => controller.reset(),
      );
    }
    return _MessageOverlay(
      title: 'WALKMAN',
      subtitle:
          'Walk the streets to eat dots. Avoid ghosts.\nNo GPS? Use the arrows.',
      buttonLabel: 'START',
      onPressed: () => controller.start(),
    );
  }
}

class _MessageOverlay extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _MessageOverlay({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xcc000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffffff00),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffffff00),
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffffff00),
                  foregroundColor: Colors.black,
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DPad extends StatelessWidget {
  final void Function(double dx, double dy) onMove;
  const _DPad({required this.onMove});

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, double dx, double dy) => SizedBox(
      width: 52,
      height: 52,
      child: OutlinedButton(
        onPressed: () => onMove(dx, dy),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xffffff00),
          side: const BorderSide(color: Color(0xffffff00), width: 2),
          backgroundColor: const Color(0xb3000000),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
    );
    const spacer = SizedBox(width: 52, height: 52);
    return Positioned(
      right: 16,
      bottom: 24,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [spacer, btn('▲', 0, 5), spacer],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [btn('◀', -5, 0), spacer, btn('▶', 5, 0)],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [spacer, btn('▼', 0, -5), spacer],
            ),
          ],
        ),
      ),
    );
  }
}
