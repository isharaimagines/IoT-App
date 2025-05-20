import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:fluttertoast/fluttertoast.dart';

final AudioPlayer _audioPlayer = AudioPlayer();

final Map<String, String> emotionSongs = {
  'Happy': 'audio/electra.mp3',
  'Sad': 'audio/we_can_fly.mp3',
  'Neutral': 'audio/weightless.mp3',
  'Chill': 'audio/careless_whisper_on_one_guitar.mp3',
  'Energetic': 'audio/narvent_distant_echoes.mp3',
  'Sleep': 'audio/piano_relaxing_sleep music.mp3'
};

final Map<String, String> emotionImages = {
  'Happy':
      'https://res.cloudinary.com/dmf5k7o0s/image/upload/nlcytumjpgsyok3iizcm.jpg',
  'Sad':
      'https://res.cloudinary.com/dmf5k7o0s/image/upload/xy2tdgexykegexc4bat3.jpg',
  'Neutral':
      'https://res.cloudinary.com/dmf5k7o0s/image/upload/j7wxl8fhyrekcxyevnny.jpg',
  'Chill':
      'https://res.cloudinary.com/dmf5k7o0s/image/upload/cra49mjuzfclslbnzxny.jpg',
  'Energetic':
      'https://res.cloudinary.com/dmf5k7o0s/image/upload/rce30elpokbpchsqmgkp.jpg',
  'Sleep':
      'https://res.cloudinary.com/dmf5k7o0s/image/upload/nlcytumjpgsyok3iizcm.jpg'
};

String getRandomSong() {
  final songs = emotionSongs.values.toList();
  final randomIndex = Random().nextInt(songs.length);
  return songs[randomIndex];
}

String getRandomImage() {
  final images = emotionImages.values.toList();
  final randomIndex = Random().nextInt(images.length);
  return images[randomIndex];
}

List<Color> _getGradientColors(double score) {
  if (score > 0.6) return [Colors.orangeAccent, Colors.pinkAccent];
  if (score >= 0.4) return [Colors.blue, Colors.purple];
  return [Colors.teal, Colors.greenAccent];
}

Color _getScoreColor(double score) {
  if (score > 0.6) return Colors.orange;
  if (score >= 0.4) return Colors.lightBlue;
  return Colors.green;
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

Future<void> _saveCurrentMeditation(
    String emotion, double windowAverage) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final faceDataRef = FirebaseFirestore.instance
      .collection('recent')
      .doc(user.uid)
      .collection('activities');

  final batch = FirebaseFirestore.instance.batch();

  String tag;
  String title;
  String about;

  if (windowAverage >= 0.7) {
    tag = 'happy';
    title = 'You’re Glowing With Joy Today!';
    about =
        "You're radiating positivity today! Embrace this joyful energy and share it with the world. Keep doing what lifts your spirit — you're on a beautiful path.";
  } else if (windowAverage >= 0.5) {
    tag = 'neutral';
    title = 'Peaceful Pause — Your Balance Is Beautiful.';
    about =
        "You're steady and grounded right now. It’s a good time to breathe deeply, reflect, and recharge. Your calm presence is your strength.";
  } else if (windowAverage >= 0.2) {
    tag = 'sad';
    title = "It's Okay To Feel Low — You’re Not Alone.";
    about =
        "It's okay to feel a bit down. These moments pass, and they make room for growth. Be kind to yourself, and take time to rest or talk to someone you trust.";
  } else {
    tag = 'angry';
    title = 'Feeling Tense — Maybe Take A Break';
    about =
        'Tension can be heavy — acknowledge it, and let it go with slow, deep breaths. You have the power to turn this moment into clarity and control.';
  }

  final docRef = faceDataRef.doc();
  batch.set(docRef, {
    'addtime': Timestamp.fromDate(DateTime.now()),
    'tag': tag,
    'emotionScore': windowAverage,
    'title': title,
    'about': about,
  });

  await batch.commit();

  Fluttertoast.showToast(
    msg: "Updating...",
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
  );
}

Future<bool> showEmotionDialog(
    BuildContext context, String emotion, double windowAverage) async {
  final String songPath = getRandomSong();
  final String imagePath = getRandomImage();
  Duration totalDuration = Duration.zero;

  return await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      bool isPlaying = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _audioPlayer.onDurationChanged.listen((Duration d) {
          totalDuration = d;
        });

        try {
          await _audioPlayer.play(AssetSource(songPath));
        } catch (e) {
          Fluttertoast.showToast(
            msg: "Error playing audio",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      });

      return StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getGradientColors(windowAverage),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () async {
                      await _audioPlayer.stop();
                      Navigator.of(context).pop(true);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'MEDITATION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Icon(
                          Icons.playlist_play_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    imagePath,
                    height: 250,
                    width: double.maxFinite,
                    fit: BoxFit.fill,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 150,
                        width: 150,
                        child: Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Personalized Insights',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 15),
                StreamBuilder<Duration>(
                  stream: _audioPlayer.onPositionChanged,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = totalDuration;

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white38,
                            thumbColor: _getScoreColor(windowAverage),
                          ),
                          child: Slider(
                            min: 0,
                            max: duration.inMilliseconds.toDouble(),
                            value: position.inMilliseconds
                                .clamp(0, duration.inMilliseconds)
                                .toDouble(),
                            onChanged: (value) async {
                              await _audioPlayer
                                  .seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white24,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                      ),
                      onPressed: () async {
                        if (isPlaying) {
                          await _audioPlayer.pause();
                        } else {
                          await _audioPlayer.resume();
                        }
                        setState(() {
                          isPlaying = !isPlaying;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.maxFinite,
                  child: TextButton.icon(
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('Got it!',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    onPressed: () async {
                      await _audioPlayer.stop();
                      await _saveCurrentMeditation(emotion, windowAverage);
                      Navigator.of(context).pop(true);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ).then((value) => value == true);
}
