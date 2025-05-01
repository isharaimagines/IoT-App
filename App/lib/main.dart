import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/io_client.dart';
import 'package:iot_app/components/device_config_page.dart';
import 'package:iot_app/components/sign_in_page.dart';
import 'package:iot_app/page/chat_page.dart';
import 'package:iot_app/page/home_page.dart';
import 'package:iot_app/page/mood_page.dart';
import 'package:iot_app/page/profle_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
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
          return FutureBuilder<bool>(
            future: _isDeviceConfigured(),
            builder: (context, configSnapshot) {
              if (configSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }
              return configSnapshot.data == true
                  ? const MainPage()
                  : const DeviceSetupPage();
            },
          );
        }

        return SignInPage();
      },
    );
  }

  Future<bool> _isDeviceConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('deviceConfigured') ?? false;
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
    _ipGetFirestore();
    _startImageFetching();
    _initHttpClient();
  }

  void _startImageFetching() {
    _fetchImage();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchImage());
  }

  void _initHttpClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..autoUncompress = false;

    _client = IOClient(httpClient);
  }

  Future<void> _fetchImage() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedIp = prefs.getString('device_ip');

      if (storedIp == null || storedIp.isEmpty) {
        return;
      }

      final uri = Uri.parse('http://$storedIp/cap-image-hi.jpg');
      final response = await _client.get(uri);

      // Validate response
      if (response.statusCode != 200) {
        throw Exception('Invalid image response');
      }

      // Process image
      final bytes = response.bodyBytes;

      // Face detection
      final faces = await _detectFaces(bytes);

      _handleFaceResults(faces);
    } on SocketException {
      throw Exception(
          'Network error. Ensure you\'re connected to the network.');
    } on Exception catch (e) {
      throw Exception(e.toString());
    } catch (e) {
      throw Exception('Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
      throw Exception('Not loading...');
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
    if (!mounted || faces.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    final faceDataRef = FirebaseFirestore.instance
        .collection('face_detections')
        .doc(user.uid)
        .collection('face_data');

    for (final face in faces) {
      await faceDataRef.add({
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

    final results = faces.map((face) {
      return '''
      Face detected:
      - Bounding box: ${face.boundingBox}
      - Head rotation: ${face.headEulerAngleY}°
      - Left eye: ${face.leftEyeOpenProbability}
      - Right eye: ${face.rightEyeOpenProbability}
      - Smilling: ${face.smilingProbability}
      
      ''';
    }).join('\n');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(faces.isEmpty
            ? 'No faces found'
            : 'Found ${faces.length} faces:\n$results'),
        duration: Duration(seconds: faces.isEmpty ? 2 : 5),
      ),
    );
  }

  @override
  void dispose() {
    _client.close();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _ipGetFirestore() async {
    // Get current user UID
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final docSnapshot = await FirebaseFirestore.instance
        .collection('deviceip')
        .doc(user.uid)
        .get();

    if (!docSnapshot.exists) throw Exception('IP document not found');

    final ip = docSnapshot.data()?['ip'];

    if (ip == null || ip.isEmpty) {
      throw Exception('IP address missing in Firestore');
    }

    if (ip.isNotEmpty) {
      return;
    }

    debugPrint(ip);

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_ip', ip);
  }

  static final _navBarTheme = NavigationBarThemeData(
    indicatorColor: Color.fromARGB(255, 200, 230, 201),
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
    const HomePage(),
    ChatPage(),
    MoodPage(),
    const ProfilePage(),
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
