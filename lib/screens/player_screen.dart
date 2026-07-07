import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/song_params.dart';
import '../services/storage_service.dart';
import 'setup_screen.dart';

class PlayerScreen extends StatefulWidget {
  final SongParams params;
  final File audioFile;
  final String fileName;

  const PlayerScreen({super.key, required this.params, required this.audioFile, required this.fileName});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _saved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _play();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  Future<void> _play() async {
    await _player.play(DeviceFileSource(widget.audioFile.path));
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final savedPath = await StorageService.saveToDevice(widget.audioFile, widget.fileName);
    setState(() {
      _saving = false;
      _saved = savedPath != null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(savedPath != null
            ? 'Saved to Music/AISongs on your device'
            : 'Could not save — storage permission may be needed'),
      ),
    );
  }

  Future<void> _exitAndCleanup() async {
    await _player.stop();
    if (!_saved) {
      await StorageService.deleteIfExists(widget.audioFile);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SetupScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    if (!_saved) {
      // best-effort cleanup if the user backs out without pressing the exit button
      StorageService.deleteIfExists(widget.audioFile);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _exitAndCleanup();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.params.name}\'s song')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.graphic_eq_rounded, size: 96, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  '${widget.params.genreLabel} · ${widget.params.moodLabel}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.params.language == AppLanguage.hindi ? 'हिन्दी' : 'English',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const Spacer(),
                IconButton(
                  iconSize: 72,
                  onPressed: _togglePlay,
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                ),
                const SizedBox(height: 16),
                if (!_saved)
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_alt_rounded),
                    label: Text(_saving ? 'Saving...' : 'Save this song'),
                  )
                else
                  const Chip(
                    avatar: Icon(Icons.check_circle, color: Colors.green, size: 18),
                    label: Text('Saved'),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _exitAndCleanup,
                  child: Text(_saved ? 'Make another song' : 'Discard and make another'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
