import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/song_params.dart';
import '../services/camera_mood_service.dart';
import '../services/music_generator.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/wav_writer.dart';
import 'setup_screen.dart';

class LiveSongScreen extends StatefulWidget {
  final String name;
  final AppLanguage language;
  final Genre genre;

  const LiveSongScreen({super.key, required this.name, required this.language, required this.genre});

  @override
  State<LiveSongScreen> createState() => _LiveSongScreenState();
}

class _LiveSongScreenState extends State<LiveSongScreen> {
  static const int segmentSeconds = 6;

  final CameraMoodService _cameraMood = CameraMoodService();
  final AudioPlayer _player = AudioPlayer();
  final TtsService _tts = TtsService();

  Mood _currentMood = Mood.neutral;
  bool _cameraReady = false;
  bool _running = false;
  bool _saved = false;
  bool _saving = false;
  int _segmentIndex = 0;
  String _status = 'Warming up the camera...';

  final List<int> _allSamples = []; // raw PCM, accumulated for Save
  File? _currentSegmentFile;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    final ok = await _cameraMood.start(onMood: (mood) {
      if (mounted) setState(() => _currentMood = mood);
    });
    if (!mounted) return;
    setState(() {
      _cameraReady = ok;
      _status = ok ? 'Reading your expression...' : 'Camera unavailable — using neutral mood.';
    });
    _runLoop();
  }

  Future<void> _runLoop() async {
    if (_running) return;
    _running = true;

    while (_running && mounted) {
      final mood = _currentMood;

      setState(() => _status = 'Shaping the song around ${_moodLabel(mood)} mood...');

      try {
        await _tts.speakLine(name: widget.name, language: widget.language, mood: mood);
      } catch (_) {
        // continue silently if TTS isn't available
      }
      if (!_running || !mounted) break;

      final samples = await compute(_generateSegment, _SegmentRequest(
        name: widget.name,
        genre: widget.genre,
        mood: mood,
        durationSeconds: segmentSeconds,
        segmentIndex: _segmentIndex,
      ));
      _segmentIndex++;
      _allSamples.addAll(samples);

      if (!_running || !mounted) break;

      final wavBytes = WavWriter.build(samples, sampleRate: MusicGenerator.sampleRate);
      final tempFile = await StorageService.writeTemp(
        wavBytes,
        'live_seg_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      final previousFile = _currentSegmentFile;
      _currentSegmentFile = tempFile;
      if (!mounted) break;

      setState(() => _status = 'Playing · ${_moodLabel(mood)}');
      await _player.play(DeviceFileSource(tempFile.path));
      await _player.onPlayerComplete.first.timeout(
        Duration(seconds: segmentSeconds + 3),
        onTimeout: () => PlayerState.completed,
      );

      if (previousFile != null) {
        await StorageService.deleteIfExists(previousFile);
      }
    }
  }

  static Uint8List _generateSegment(_SegmentRequest req) {
    return Uint8List.fromList(MusicGenerator.generateSegmentSamples(
      name: req.name,
      genre: req.genre,
      mood: req.mood,
      durationSeconds: req.durationSeconds,
      segmentIndex: req.segmentIndex,
    ));
  }

  Future<void> _stopAndExit({required bool save}) async {
    setState(() => _running = false);
    await _player.stop();

    if (save && _allSamples.isNotEmpty) {
      setState(() => _saving = true);
      final wavBytes = WavWriter.build(_allSamples, sampleRate: MusicGenerator.sampleRate);
      final fileName = 'aisong_${DateTime.now().millisecondsSinceEpoch}.wav';
      final tempFile = await StorageService.writeTemp(wavBytes, fileName);
      final savedPath = await StorageService.saveToDevice(tempFile, fileName);
      await StorageService.deleteIfExists(tempFile);
      setState(() {
        _saving = false;
        _saved = savedPath != null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(savedPath != null
              ? 'Saved to Music/AISongs on your device'
              : 'Could not save — storage permission may be needed')),
        );
      }
    }

    if (_currentSegmentFile != null) {
      await StorageService.deleteIfExists(_currentSegmentFile!);
    }

    await _cameraMood.dispose();
    _tts.dispose();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SetupScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _running = false;
    _player.dispose();
    _cameraMood.dispose();
    _tts.dispose();
    if (_currentSegmentFile != null && !_saved) {
      StorageService.deleteIfExists(_currentSegmentFile!);
    }
    super.dispose();
  }

  String _moodLabel(Mood m) {
    switch (m) {
      case Mood.happy:
        return 'Happy';
      case Mood.neutral:
        return 'Neutral';
      case Mood.sad:
        return 'Sad';
      case Mood.energetic:
        return 'Energetic';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraMood.controller;
    return WillPopScope(
      onWillPop: () async {
        await _stopAndExit(save: false);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.name}\'s live song')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _cameraReady && controller != null && controller.value.isInitialized
                        ? CameraPreview(controller)
                        : Container(
                            color: Colors.white10,
                            alignment: Alignment.center,
                            child: const Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white30),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  '${_genreLabel(widget.genre)} · currently ${_moodLabel(_currentMood)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _stopAndExit(save: true),
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_alt_rounded),
                      label: Text(_saving ? 'Saving...' : 'Stop & save'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _saving ? null : () => _stopAndExit(save: false),
                      child: const Text('Stop & discard'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _genreLabel(Genre g) {
    switch (g) {
      case Genre.pop:
        return 'Pop';
      case Genre.rap:
        return 'Rap';
      case Genre.country:
        return 'Country';
      case Genre.rock:
        return 'Rock';
      case Genre.lofi:
        return 'Lo-fi';
    }
  }
}

class _SegmentRequest {
  final String name;
  final Genre genre;
  final Mood mood;
  final int durationSeconds;
  final int segmentIndex;

  _SegmentRequest({
    required this.name,
    required this.genre,
    required this.mood,
    required this.durationSeconds,
    required this.segmentIndex,
  });
}
