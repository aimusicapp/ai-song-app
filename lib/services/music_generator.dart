import 'dart:math';
import 'dart:typed_data';
import '../models/song_params.dart';
import 'wav_writer.dart';

/// Generates a short, unique instrumental track entirely on-device.
/// The melody pattern is deterministically seeded from the user's name,
/// so the same name + genre + mood always makes the same tune, but every
/// different name produces a different one. No internet, no API key.
class MusicGenerator {
  static const int sampleRate = 22050;

  /// Generates one short segment of raw PCM samples (no WAV header) for the
  /// given mood. segmentIndex lets consecutive segments of the same mood
  /// still vary slightly instead of repeating identically.
  static List<int> generateSegmentSamples({
    required String name,
    required Genre genre,
    required Mood mood,
    required int durationSeconds,
    int segmentIndex = 0,
  }) {
    final int seed = _seedFromString('$name-${_genreKey(genre)}-${_moodKey(mood)}-$segmentIndex');
    final Random rnd = Random(seed);

    final _GenreProfile profile = _profileFor(genre);
    final _MoodProfile moodProfile = _moodFor(mood);

    final List<double> scale = _scaleFor(profile.baseFreq, moodProfile.isMinor);
    final double bpm = profile.bpm * moodProfile.tempoMultiplier;
    final double beatSeconds = 60.0 / bpm;
    final double noteSeconds = beatSeconds * profile.noteBeats;

    final int totalSamples = sampleRate * durationSeconds;
    final List<double> buffer = List<double>.filled(totalSamples, 0.0);

    // ---- Melody layer ----
    double t = 0.0;
    int lastIndex = rnd.nextInt(scale.length);
    while (t < durationSeconds) {
      final int step = rnd.nextInt(5) - 2; // -2..2
      final int idx = (lastIndex + step).clamp(0, scale.length - 1);
      lastIndex = idx;
      final double freq = scale[idx];
      _addTone(
        buffer,
        startSec: t,
        durationSec: noteSeconds * 0.92,
        freq: freq,
        amplitude: 0.28,
        waveform: profile.waveform,
      );
      t += noteSeconds;
    }

    // ---- Bass drone layer ----
    t = 0.0;
    final double bassFreq = profile.baseFreq / 2;
    while (t < durationSeconds) {
      _addTone(
        buffer,
        startSec: t,
        durationSec: beatSeconds * 4 * 0.95,
        freq: bassFreq,
        amplitude: 0.16,
        waveform: _Waveform.sine,
      );
      t += beatSeconds * 4;
    }

    // ---- Percussion layer ----
    t = 0.0;
    int beatCount = 0;
    while (t < durationSeconds) {
      final bool accent = beatCount % profile.accentEvery == 0;
      _addPercussionHit(
        buffer,
        startSec: t,
        amplitude: accent ? 0.3 : 0.18,
        sharp: profile.percussionSharp,
        rnd: rnd,
      );
      t += beatSeconds;
      beatCount++;
    }

    // Amplitudes above are chosen conservatively so overlap rarely exceeds
    // +/-1.0; we just hard-clip as a safety net rather than scanning the
    // whole buffer for a peak (segments are generated one at a time live).
    final List<int> pcm = List<int>.filled(totalSamples, 0);
    for (int i = 0; i < totalSamples; i++) {
      final double v = buffer[i].clamp(-1.0, 1.0);
      pcm[i] = (v * 32000).round();
    }
    return pcm;
  }

  /// One-shot full song generation, used when the camera is off and the
  /// mood is fixed upfront for the whole track.
  static Uint8List generate({required SongParams params, int durationSeconds = 22}) {
    final samples = generateSegmentSamples(
      name: params.name,
      genre: params.genre,
      mood: params.mood,
      durationSeconds: durationSeconds,
    );
    return WavWriter.build(samples, sampleRate: sampleRate);
  }

  static int _seedFromString(String s) {
    int hash = 0;
    for (final code in s.toLowerCase().codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    if (hash == 0) hash = 42;
    return hash;
  }

  static void _addTone(
    List<double> buffer, {
    required double startSec,
    required double durationSec,
    required double freq,
    required double amplitude,
    required _Waveform waveform,
  }) {
    final int startSample = (startSec * sampleRate).round();
    final int lengthSamples = (durationSec * sampleRate).round();
    for (int i = 0; i < lengthSamples; i++) {
      final int idx = startSample + i;
      if (idx < 0 || idx >= buffer.length) continue;
      final double time = i / sampleRate;
      final double envelope = _envelope(i / lengthSamples);
      double sample;
      final double phase = 2 * pi * freq * time;
      switch (waveform) {
        case _Waveform.sine:
          sample = sin(phase);
          break;
        case _Waveform.square:
          sample = sin(phase) >= 0 ? 1.0 : -1.0;
          sample *= 0.6; // soften harsh square
          break;
        case _Waveform.saw:
          sample = 2 * (freq * time - (freq * time).floorToDouble()) - 1;
          sample *= 0.7;
          break;
      }
      buffer[idx] += sample * amplitude * envelope;
    }
  }

  static void _addPercussionHit(
    List<double> buffer, {
    required double startSec,
    required double amplitude,
    required bool sharp,
    required Random rnd,
  }) {
    final int startSample = (startSec * sampleRate).round();
    final int hitLength = (sampleRate * (sharp ? 0.05 : 0.11)).round();
    for (int i = 0; i < hitLength; i++) {
      final int idx = startSample + i;
      if (idx < 0 || idx >= buffer.length) continue;
      final double decay = exp(-i / (hitLength * 0.25));
      final double noise = (rnd.nextDouble() * 2 - 1);
      buffer[idx] += noise * amplitude * decay;
    }
  }

  static double _envelope(double posFraction) {
    // quick attack, gentle release to avoid clicks between notes
    const double attack = 0.08;
    const double release = 0.25;
    if (posFraction < attack) return posFraction / attack;
    if (posFraction > 1 - release) return (1 - posFraction) / release;
    return 1.0;
  }

  static List<double> _scaleFor(double baseFreq, bool isMinor) {
    // intervals in semitones from root, one octave + a bit
    final List<int> majorIntervals = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16];
    final List<int> minorIntervals = [0, 2, 3, 5, 7, 8, 10, 12, 14, 15];
    final intervals = isMinor ? minorIntervals : majorIntervals;
    return intervals.map((semi) => baseFreq * pow(2, semi / 12)).toList();
  }

  static String _genreKey(Genre genre) => genre.toString();
  static String _moodKey(Mood mood) => mood.toString();

  static _GenreProfile _profileFor(Genre genre) {
    switch (genre) {
      case Genre.pop:
        return _GenreProfile(baseFreq: 261.6, bpm: 112, noteBeats: 0.5, waveform: _Waveform.sine, accentEvery: 4, percussionSharp: false);
      case Genre.rap:
        return _GenreProfile(baseFreq: 220.0, bpm: 92, noteBeats: 0.25, waveform: _Waveform.square, accentEvery: 4, percussionSharp: true);
      case Genre.country:
        return _GenreProfile(baseFreq: 293.7, bpm: 104, noteBeats: 0.5, waveform: _Waveform.saw, accentEvery: 2, percussionSharp: false);
      case Genre.rock:
        return _GenreProfile(baseFreq: 246.9, bpm: 128, noteBeats: 0.33, waveform: _Waveform.square, accentEvery: 4, percussionSharp: true);
      case Genre.lofi:
        return _GenreProfile(baseFreq: 233.1, bpm: 78, noteBeats: 0.75, waveform: _Waveform.sine, accentEvery: 4, percussionSharp: false);
    }
  }

  static _MoodProfile _moodFor(Mood mood) {
    switch (mood) {
      case Mood.happy:
        return _MoodProfile(isMinor: false, tempoMultiplier: 1.08);
      case Mood.neutral:
        return _MoodProfile(isMinor: false, tempoMultiplier: 1.0);
      case Mood.sad:
        return _MoodProfile(isMinor: true, tempoMultiplier: 0.85);
      case Mood.energetic:
        return _MoodProfile(isMinor: false, tempoMultiplier: 1.2);
    }
  }
}

enum _Waveform { sine, square, saw }

class _GenreProfile {
  final double baseFreq;
  final double bpm;
  final double noteBeats;
  final _Waveform waveform;
  final int accentEvery;
  final bool percussionSharp;

  _GenreProfile({
    required this.baseFreq,
    required this.bpm,
    required this.noteBeats,
    required this.waveform,
    required this.accentEvery,
    required this.percussionSharp,
  });
}

class _MoodProfile {
  final bool isMinor;
  final double tempoMultiplier;
  _MoodProfile({required this.isMinor, required this.tempoMultiplier});
}
