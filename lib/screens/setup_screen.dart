import 'package:flutter/material.dart';
import '../models/song_params.dart';
import 'live_song_screen.dart';
import 'generating_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  AppLanguage _language = AppLanguage.english;
  Genre _genre = Genre.pop;
  Mood _manualMood = Mood.happy;
  bool _useCamera = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name first')),
      );
      return;
    }

    if (_useCamera) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveSongScreen(
            name: name,
            language: _language,
            genre: _genre,
          ),
        ),
      );
    } else {
      final params = SongParams(name: name, language: _language, genre: _genre, mood: _manualMood);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GeneratingScreen(params: params)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make it yours')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Your name', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Prince',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Language', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<AppLanguage>(
              segments: const [
                ButtonSegment(value: AppLanguage.english, label: Text('English')),
                ButtonSegment(value: AppLanguage.hindi, label: Text('हिन्दी')),
              ],
              selected: {_language},
              onSelectionChanged: (s) => setState(() => _language = s.first),
            ),
            const SizedBox(height: 24),

            const Text('Song type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Genre.values.map((g) {
                final selected = g == _genre;
                return ChoiceChip(
                  label: Text(_genreLabel(g)),
                  selected: selected,
                  onSelected: (_) => setState(() => _genre = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use camera live', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('The song follows your expression in real time as it plays'),
              value: _useCamera,
              onChanged: (v) => setState(() => _useCamera = v),
            ),

            if (!_useCamera) ...[
              const SizedBox(height: 8),
              const Text('Mood', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: Mood.values.map((m) {
                  final selected = m == _manualMood;
                  return ChoiceChip(
                    label: Text(_moodLabel(m)),
                    selected: selected,
                    onSelected: (_) => setState(() => _manualMood = m),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 32),
            FilledButton(
              onPressed: _continue,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(_useCamera ? 'Start my live song' : 'Generate my song'),
            ),
          ],
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
}
