import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late http.Client _client;
  Uint8List? _imageBytes;
  String _errorMessage = '';
  bool _isLoading = false;
  Timer? _timer;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initHttpClient();
    _startImageFetching();
  }

  void _initHttpClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..autoUncompress = false;

    _client = IOClient(httpClient);
  }

  Future<XFile?> pickImage() async {
    final ImagePicker _picker = ImagePicker();
    // Capture a photo
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    return photo;
  }

  Future<void> _fetchImage() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final uri = Uri.parse('http://192.168.213.13/cap-image-hi.jpg');
      final response = await _client.get(uri);

      // Validate response
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('Invalid image response');
      }

      // Process image
      final bytes = response.bodyBytes;
      await _validateImage(bytes);

      // Face detection
      // final faces = await _detectFaces(bytes);
      // _handleFaceResults(faces);

      setState(() => _imageBytes = bytes);
    } on TimeoutException {
      setState(() =>
          _errorMessage = 'Request timed out. Check the device connection.');
    } on SocketException {
      setState(() => _errorMessage =
          'Network error. Ensure you\'re connected to the network.');
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString());
    } catch (e) {
      setState(() => _errorMessage = 'Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Face>> _detectFaces(Uint8List imageBytes) async {
    final inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      metadata: InputImageMetadata(
        size:
            Size(800, 600), // Adjust this based on your actual image resolution
        rotation:
            InputImageRotation.rotation0deg, // Adjust if your camera rotates
        format: InputImageFormat
            .nv21, // Correct format for camera raw frames (NV21)
        bytesPerRow: 800, // Only needed for raw formats (use image width)
      ),
    );

    return await _faceDetector.processImage(inputImage);
  }

  void _handleFaceResults(List<Face> faces) {
    if (!mounted) return;

    final results = faces.map((face) {
      return '''
      Face detected:
      - Bounding box: ${face.boundingBox}
      - Head rotation: ${face.headEulerAngleY}°
      - Smiling: ${face.smilingProbability?.toStringAsFixed(2)}
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

  Future<void> _validateImage(Uint8List bytes) async {
    // Example validation: Check if bytes can be decoded as an image
    await precacheImage(MemoryImage(bytes), context);
  }

  void _startImageFetching() {
    _fetchImage();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchImage());
  }

  @override
  void dispose() {
    _client.close();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? photoUrl = user?.photoURL;
    final String? displayName = user?.displayName ?? 'Guest';

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : AssetImage('assets/unknown-icon.jpg') as ImageProvider,
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey ${displayName ?? 'Unknown'}!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'How are you today?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 18),
            Text(
              'Status',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchImage,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty)
      return Center(child: Text(_errorMessage, textAlign: TextAlign.center));
    if (_imageBytes == null)
      return const Center(
          child: Text('Tap the refresh button to load an image.'));

    return Image.memory(
      _imageBytes!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text('Failed to display image:\n$error', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
