import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:walkman/game/geo.dart';
import 'package:walkman/game_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eating a dot sends a haptic to the platform', () async {
    final haptics = <Object?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    // Audio plugin isn't available in tests; swallow its channel calls.
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => null,
    );

    final c = GameController();
    const origin = LatLng(61.4995, 23.7575);
    c.moveTo(origin); // starts setup; network is blocked in tests -> grid
    for (var i = 0; i < 200 && !c.started; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(c.started, isTrue);
    expect(haptics, isEmpty);

    final dot = offsetLatLng(origin, 25, 0); // grid dot 25 m east
    c.moveTo(dot);
    expect(c.score, 0, reason: 'eating waits for the drawn sprite');
    c.eatAt(dot, 10);
    expect(c.score, greaterThan(0));
    expect(haptics, contains('HapticFeedbackType.lightImpact'));

    c.dispose();
  });
}
