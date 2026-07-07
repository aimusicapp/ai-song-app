enum AppLanguage { hindi, english }

enum Genre { pop, rap, country, rock, lofi }

enum Mood { happy, neutral, sad, energetic }

class SongParams {
  final String name;
  final AppLanguage language;
  final Genre genre;
  final Mood mood;

  SongParams({
    required this.name,
    required this.language,
    required this.genre,
    required this.mood,
  });

  String get genreLabel {
    switch (genre) {
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

  String get moodLabel {
    switch (mood) {
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
