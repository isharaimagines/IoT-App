import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

final AudioPlayer _audioPlayer = AudioPlayer();

final Map<String, String> emotionSongs = {
  'Happy': 'audio/electra.mp3',
  'Sad': 'audio/we_can_fly.mp3',
  'Neutral': 'audio/weightless.mp3',
  'Chill': 'audio/careless_whisper_on_one_guitar.mp3',
  'Energetic': 'audio/narvent_distant_echoes.mp3',
  'Sleep': 'audio/piano_relaxing_sleep music.mp3'
};

String getRandomSong() {
  final songs = emotionSongs.values.toList();
  final randomIndex = Random().nextInt(songs.length);
  return songs[randomIndex];
}

List<Color> _getGradientColors(String emotion) {
  switch (emotion.toLowerCase()) {
    case 'Happy':
      return [Colors.orangeAccent, Colors.pinkAccent];
    case 'Sad':
      return [Colors.blue, Colors.purple];
    default:
      return [Colors.teal, Colors.greenAccent];
  }
}

Color _getScoreColor(double score) {
  if (score > 6) return Colors.green;
  if (score > 4) return Colors.orange;
  return Colors.red;
}

String getEmotionImage(String emotion) {
  const baseUrl = 'https://res.cloudinary.com/dmf5k7o0s/image/upload/';
  switch (emotion.toLowerCase()) {
    case 'Happy':
      return '${baseUrl}v1747596694/opatvsqqiozrdvcjl6m1.jpg';
    case 'Sad':
      return '${baseUrl}v1747596694/opatvsqqiozrdvcjl6m1.jpg';
    default:
      return '${baseUrl}v1747596694/opatvsqqiozrdvcjl6m1.jpg';
  }
}

String getEmotionQuote(String emotion) {
  switch (emotion.toLowerCase()) {
    case 'Happy':
      return '“Happiness is not something ready made. It comes from your own actions.” - Dalai Lama';
    case 'Sad':
      return '“The sun will rise and we will try again.” - Unknown';
    default:
      return '“Peace begins with a smile.” - Mother Teresa';
  }
}

void showEmotionDialog(
    BuildContext context, String emotion, double windowAverage) async {
  final String songPath = getRandomSong();

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getGradientColors(emotion),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                'Your Mood Companion',
                style: GoogleFonts.lobster(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                getEmotionImage(emotion),
                height: 150,
                width: 150,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 150,
                    width: 150,
                    child: Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                  );
                },
                errorBuilder: (context, error, _) => const SizedBox(
                  height: 150,
                  width: 150,
                  child: Center(
                    child: Icon(Icons.mood_outlined,
                        size: 40, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Mood Score: ${windowAverage.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (windowAverage / 10).clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              color: _getScoreColor(windowAverage),
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                getEmotionQuote(emotion),
                textAlign: TextAlign.center,
                style: GoogleFonts.dancingScript(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  onPressed: () async {
                    try {
                      await _audioPlayer.play(AssetSource(songPath));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error playing audio: $e')));
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.pause, color: Colors.white),
                  onPressed: () => _audioPlayer.pause(),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label:
                  const Text('Got it!', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white24,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                _audioPlayer.stop();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('_isDialogShowing', false);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
