import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:iot_app/components/sign_in_page.dart';
import 'package:iot_app/page/chat_page.dart';
import 'package:iot_app/page/home_page.dart';
import 'package:iot_app/page/mood_page.dart';
import 'package:iot_app/page/profle_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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
  bool _isDisposed = false; // Track if widget is disposed

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
      enableClassification: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initHttpClient();
    _startImageFetching();
  }

  void _startImageFetching() {
    // Cancel any existing timer
    _timer?.cancel();

    // Initial fetch
    if (!_isDisposed) {
      _fetchImage();
    }

    // Set up periodic fetching
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!_isDisposed) {
        _fetchImage();
      } else {
        timer.cancel();
      }
    });
  }

  void _initHttpClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (cert, host, port) => true; // For testing only
    _client = IOClient(httpClient);
  }

  Future<void> _fetchImage() async {
    if (_isLoading || _isDisposed) return;

    _safeSetState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _isDisposed) return;

      final docSnapshot = await FirebaseFirestore.instance
          .collection('deviceip')
          .doc(user.uid)
          .get();

      if (_isDisposed) return;

      if (!docSnapshot.exists || !docSnapshot.data()!.containsKey('ip')) {
        return;
      }

      final storedIp = docSnapshot.data()!['ip'] as String;
      final uri = Uri.parse('http://$storedIp/cap-image-hi.jpg');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('Invalid image response');
      }

      final bytes = response.bodyBytes;
      final faces = await _detectFaces(bytes);

      if (!_isDisposed) {
        await _handleFaceResults(faces);
      }
    } catch (e) {
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error-: ${e.toString()}')),
        );
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
    final file = File('${tempDir.path}/temp_img.jpg');
    await file.writeAsBytes(imageBytes);

    final inputImage = InputImage.fromFilePath(file.path);
    return await _faceDetector.processImage(inputImage);
  }

  Future<void> _handleFaceResults(List<Face> faces) async {
    if (_isDisposed || faces.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final faceDataRef = FirebaseFirestore.instance
        .collection('face_detections')
        .doc(user.uid)
        .collection('face_data');

    // Batch write for better performance
    final batch = FirebaseFirestore.instance.batch();

    for (final face in faces) {
      final docRef = faceDataRef.doc();
      batch.set(docRef, {
        'timestamp': now.toIso8601String(),
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

    if (!_isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${faces.length} faces'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // New emotion detection logic
    final faceDataQuery = await FirebaseFirestore.instance
        .collection('face_detections')
        .doc(user.uid)
        .collection('face_data')
        .orderBy('timestamp', descending: true)
        .limit(4)
        .get();

    final smilingProbs = faceDataQuery.docs
        .map((doc) => doc.data()['smilingProbability'] as double?)
        .where((prob) => prob != null)
        .cast<double>()
        .toList();

    if (smilingProbs.isEmpty) return;

    final windowAverage =
        smilingProbs.reduce((a, b) => a + b) / smilingProbs.length;

    String emotion;
    if (windowAverage >= 0.6) {
      emotion = 'Happy 😊';
    } else if (windowAverage >= 0.4) {
      emotion = 'Neutral 😐';
    } else {
      emotion = 'Sad 😢';
    }

    if (!_isDisposed && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Mood Analysis'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image from network URL
              Image.network(
                "https://res.cloudinary.com/dmf5k7o0s/image/upload/v1747596694/opatvsqqiozrdvcjl6m1.jpg", // Implement this function
                height: 120,
                width: 120,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const CircularProgressIndicator();
                },
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.error_outline),
              ),
              const SizedBox(height: 16),
              Text(
                  'Your average mood score: ${windowAverage.toStringAsFixed(2)}\n$emotion'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // Mark as disposed first
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
