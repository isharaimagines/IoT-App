import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:iot_app/components/show_emotion_dialog.dart';
import 'package:iot_app/components/sign_in_page.dart';
import 'package:iot_app/page/chat_page.dart';
import 'package:iot_app/page/home_page.dart';
import 'package:iot_app/page/mood_page.dart';
import 'package:iot_app/page/profle_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

  runApp(
    MaterialApp(
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: true,
    ),
  );
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasData) {
          return const MainPage(); // Add this redirect if needed
        }

        return SignInPage();
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  Timer? _timer;
  late http.Client _client;
  bool _isLoading = false;
  bool _isDisposed = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isDialogShowing = false;
  String deviceIPAddress = '';
  late Duration _fetchInterval;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
      enableClassification: true,
    ),
  );

  Future<void> _startImageFetching() async {
    _timer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final savedSeconds = prefs.getInt('fetchIntervalSeconds') ?? 20;
    setState(() {
      _fetchInterval = Duration(seconds: savedSeconds);
    });

    _timer = Timer.periodic(_fetchInterval, (timer) {
      if (!_isDisposed) {
        _fetchImage();
      } else {
        timer.cancel();
      }
    });
  }

  void _initHttpClient() {
    final httpClient = HttpClient();
    _client = IOClient(httpClient);
  }

  Future<void> _fetchImage() async {
    if (_isLoading || _isDisposed) return;

    _safeSetState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();

    setState(() {
      deviceIPAddress = prefs.getString('deviceIPAddress') ?? '192.168.45.13';
    });

    try {
      final uri = Uri.parse('http://$deviceIPAddress/cap-image-hi.jpeg');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        Fluttertoast.showToast(
          msg: "Invalid image response",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      final bytes = response.bodyBytes;
      final faces = await _detectFaces(bytes);

      if (!_isDisposed) {
        await _handleFaceResults(faces);
      }
    } catch (e) {
      if (!_isDisposed) {
        _safeSetState(() => _isLoading = false);
      }
    } finally {
      if (!_isDisposed) {
        _safeSetState(() => _isLoading = false);
      }
    }
  }

  // Helper method for safe state updates
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Future<List<Face>> _detectFaces(Uint8List imageBytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/temp_img.jpeg');
    await file.writeAsBytes(imageBytes);

    final inputImage = InputImage.fromFilePath(file.path);
    return await _faceDetector.processImage(inputImage);
  }

  Future<void> _handleFaceResults(List<Face> faces) async {
    if (_isDisposed || faces.isEmpty) return;

    Fluttertoast.showToast(
      msg: "Found ${faces.length} faces",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final faceDataRef = FirebaseFirestore.instance
        .collection('face_detections')
        .doc(user.uid)
        .collection('face_data');

    final batch = FirebaseFirestore.instance.batch();

    for (final face in faces) {
      final docRef = faceDataRef.doc();
      batch.set(docRef, {
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'boundingBox': {
          'left': face.boundingBox.left,
          'top': face.boundingBox.top,
          'right': face.boundingBox.right,
          'bottom': face.boundingBox.bottom,
        },
        'headEulerAngleY': face.headEulerAngleY,
        'smilingProbability': face.smilingProbability,
        'leftEyeOpenProbability': face.leftEyeOpenProbability,
        'rightEyeOpenProbability': face.rightEyeOpenProbability,
      });
    }

    await batch.commit();

    final faceDataQuery =
        await faceDataRef.orderBy('timestamp', descending: true).limit(4).get();

    final smilingProbs = faceDataQuery.docs
        .map((doc) => doc.data()['smilingProbability'] as double?)
        .whereType<double>()
        .toList();

    if (smilingProbs.isEmpty) return;

    final windowAverage =
        smilingProbs.reduce((a, b) => a + b) / smilingProbs.length;

    String emotion;
    if (windowAverage >= 0.08) {
      emotion = 'genuine happiness';
    } else if (windowAverage >= 0.06) {
      emotion = 'moderate happiness';
      if (!_isDialogShowing && mounted) {
        _isDialogShowing = true;

        final done = await showEmotionDialog(context, emotion, windowAverage);

        if (mounted && done) {
          setState(() {
            _isDialogShowing = false;
          });
        }
      }
    } else if (windowAverage >= 0.03) {
      emotion = 'uncomfortable';
      if (!_isDialogShowing && mounted) {
        _isDialogShowing = true;

        final done = await showEmotionDialog(context, emotion, windowAverage);

        if (mounted && done) {
          setState(() {
            _isDialogShowing = false;
          });
        }
      }
    } else if (windowAverage >= 0) {
      emotion = 'sad';
      if (!_isDialogShowing && mounted) {
        _isDialogShowing = true;

        final done = await showEmotionDialog(context, emotion, windowAverage);

        if (mounted && done) {
          setState(() {
            _isDialogShowing = false;
          });
        }
      }
    } else {
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    _initHttpClient();
    _startImageFetching();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioPlayer.dispose();
    _timer?.cancel();
    _client.close();
    _faceDetector.close();
    super.dispose();
  }

  static final _navBarTheme = NavigationBarThemeData(
    indicatorColor: Color.fromRGBO(200, 230, 201, 1),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
  );

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today),
      label: 'Today',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat),
      label: 'Chat',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: 'Memories',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  final List<Widget> _screens = [
    HomePage(),
    ChatPage(),
    MoodPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: _navBarTheme,
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: _destinations,
        ),
      ),
    );
  }
}
