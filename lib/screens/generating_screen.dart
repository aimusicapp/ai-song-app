import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/song_params.dart';
import '../services/music_generator.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import 'player_screen.dart';

class GeneratingScreen extends StatefulWidget {
  final SongParams params;
  const GeneratingScreen({super.key, required this.params});

  @override
  State<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<GeneratingScreen> {
  final List<String> _messages = [
    'Reading the vibe...',
    'Tuning the melody...',
    'Laying down the beat...',
    'Mixing your track...',
  ];
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _cycleMessages();
    _generate();
  }

  void _cycleMessages() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return false;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
      return true;
    });
  }

  Future<void> _generate() async {
    // Run the actual synthesis off the UI thread so the app stays smooth.
    final Uint8List audioBytes = await compute(_generateInIsolate, widget.params);

    final String fileName = 'aisong_${DateTime.now().millisecondsSinceEpoch}.wav';
    final tempFile = await StorageService.writeTemp(audioBytes, fileName);

    // Speak the personalized intro line, then hand off to the player.
    final tts = TtsService();
    try {
      await tts.speakLine(name: widget.params.name, language: widget.params.language, mood: widget.params.mood);
    } catch (_) {
      // if TTS isn't available on this device, just continue silently
    } finally {
      tts.dispose();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(params: widget.params, audioFile: tempFile, fileName: fileName),
      ),
    );
  }

  static Uint8List _generateInIsolate(SongParams params) {
    return MusicGenerator.generate(params: params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 24),
            Text(
              _messages[_messageIndex],
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'for ${widget.params.name} · ${widget.params.genreLabel} · ${widget.params.moodLabel}',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
