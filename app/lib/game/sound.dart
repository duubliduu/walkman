import 'dart:math' as math;
import 'dart:typed_data';

/// Generates a small mono 16-bit PCM WAV file with a triangle-wave tone that
/// linearly sweeps from [fromHz] to [toHz] over [seconds], fading out
/// linearly (matches the `tone()` synth in index.html, minus Web Audio).
Uint8List generateToneWav({
  required double fromHz,
  required double toHz,
  required double seconds,
  int sampleRate = 22050,
}) {
  final numSamples = (seconds * sampleRate).round();
  final data = ByteData(numSamples * 2);
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    // Instantaneous phase = integral of 2*pi*freq(t) dt for a linear sweep.
    final phase =
        2 * math.pi * (fromHz * t + (toHz - fromHz) * t * t / (2 * seconds));
    final p = (phase / (2 * math.pi)) % 1.0;
    final triangle = p < 0.5 ? (4 * p - 1) : (3 - 4 * p);
    final gain = 0.3 * (1 - t / seconds).clamp(0.0, 1.0);
    final sample = (triangle * gain * 32767).clamp(-32768, 32767).round();
    data.setInt16(i * 2, sample, Endian.little);
  }
  return _wrapWav(data.buffer.asUint8List(), sampleRate);
}

Uint8List _wrapWav(Uint8List pcm, int sampleRate) {
  const channels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final header = BytesBuilder();

  void writeAscii(String s) => header.add(s.codeUnits);
  void writeU32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    header.add(b.buffer.asUint8List());
  }

  void writeU16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    header.add(b.buffer.asUint8List());
  }

  writeAscii('RIFF');
  writeU32(36 + pcm.length);
  writeAscii('WAVE');
  writeAscii('fmt ');
  writeU32(16);
  writeU16(1); // PCM
  writeU16(channels);
  writeU32(sampleRate);
  writeU32(byteRate);
  writeU16(blockAlign);
  writeU16(bitsPerSample);
  writeAscii('data');
  writeU32(pcm.length);

  final out = BytesBuilder();
  out.add(header.toBytes());
  out.add(pcm);
  return out.toBytes();
}

/// Pre-generated sound effects, matching index.html's sweeps.
class GameSounds {
  final Uint8List wakaA = generateToneWav(
    fromHz: 500,
    toHz: 250,
    seconds: 0.12,
  );
  final Uint8List wakaB = generateToneWav(
    fromHz: 250,
    toHz: 500,
    seconds: 0.12,
  );
  final Uint8List power = generateToneWav(fromHz: 300, toHz: 900, seconds: 0.3);
  final Uint8List caught = generateToneWav(
    fromHz: 700,
    toHz: 100,
    seconds: 0.8,
  );
}
