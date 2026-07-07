import 'dart:async';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/song_params.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  final Random _rnd = Random();

  Future<void> speakLine({required String name, required AppLanguage language, required Mood mood}) async {
    final String langCode = language == AppLanguage.hindi ? 'hi-IN' : 'en-IN';
    final String line = _pickLine(name: name, language: language, mood: mood);

    try {
      await _tts.setLanguage(langCode);
    } catch (_) {
      // fall back to default device voice if hi-IN / en-IN isn't installed
    }
    await _tts.setPitch(1.05);
    await _tts.setSpeechRate(0.9);

    final Completer<void> completer = Completer<void>();
    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _tts.setErrorHandler((msg) {
      if (!completer.isCompleted) completer.complete();
    });

    await _tts.speak(line);
    await completer.future.timeout(const Duration(seconds: 6), onTimeout: () {});
  }

  String _pickLine({required String name, required AppLanguage language, required Mood mood}) {
    final lines = language == AppLanguage.hindi ? _hindiLines(name, mood) : _englishLines(name, mood);
    return lines[_rnd.nextInt(lines.length)];
  }

  List<String> _englishLines(String name, Mood mood) {
    switch (mood) {
      case Mood.happy:
        return [
          '$name, that smile is the whole song right now.',
          'This beat is lighting up just for $name.',
          '$name is glowing, so let\'s speed things up.',
        ];
      case Mood.sad:
        return [
          'Take it slow, $name, this one\'s gentle for you.',
          '$name, the melody\'s here to sit with you a while.',
          'Softly now, $name, we\'ve got you.',
        ];
      case Mood.energetic:
        return [
          '$name is bringing the energy, let\'s go!',
          'Turning it up for $name right now.',
          '$name\'s on fire, keep that momentum!',
        ];
      case Mood.neutral:
        return [
          'Keep going, $name, the rhythm\'s still yours.',
          '$name, let\'s see where this one takes us.',
          'Steady and easy, this one\'s for $name.',
        ];
    }
  }

  List<String> _hindiLines(String name, Mood mood) {
    switch (mood) {
      case Mood.happy:
        return [
          '$name, yeh muskaan hi gaana ban gayi.',
          '$name ke liye yeh beat aur tez ho raha hai.',
        ];
      case Mood.sad:
        return [
          'Aaram se, $name, yeh dhun aapke saath hai.',
          '$name, thoda dheere, hum yahin hain.',
        ];
      case Mood.energetic:
        return [
          '$name, yeh energy zabardast hai, chaliye!',
          '$name ke liye speed badha rahe hain.',
        ];
      case Mood.neutral:
        return [
          '$name, yeh gaana chal raha hai aapke liye.',
          'Chaliye $name, dekhte hain yeh kahan jaata hai.',
        ];
    }
  }

  void dispose() {
    _tts.stop();
  }
}
