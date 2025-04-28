// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:google_ml_kit/google_ml_kit.dart';
// import 'package:http/http.dart' as http;
// // import 'package:image/image.dart' as img;
// import 'package:http/io_client.dart';
// import 'package:multicast_dns/multicast_dns.dart';
// // import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// // import 'package:path_provider/path_provider.dart';

// class MDNSDiscovery {
//   final MDnsClient _mdnsClient = MDnsClient();

//   Future<String?> discoverESP32IP(String serviceName) async {
//     try {
//       await _mdnsClient.start();
//       await for (final PtrResourceRecord ptr
//           in _mdnsClient.lookup<PtrResourceRecord>(
//               ResourceRecordQuery.serverPointer(serviceName))) {
//         await for (final SrvResourceRecord srv
//             in _mdnsClient.lookup<SrvResourceRecord>(
//                 ResourceRecordQuery.service(ptr.domainName))) {
//           await for (final IPAddressResourceRecord ip
//               in _mdnsClient.lookup<IPAddressResourceRecord>(
//                   ResourceRecordQuery.addressIPv4(srv.target))) {
//             _mdnsClient.stop();
//             return ip.address.address;
//           }
//         }
//       }
//       _mdnsClient.stop();
//       return null;
//     } catch (e) {
//       _mdnsClient.stop();
//       return null;
//     }
//   }
// }

// class ChatPage extends StatefulWidget {
//   const ChatPage({super.key});

//   @override
//   State<ChatPage> createState() => _ChatPageState();
// }

// class _ChatPageState extends State<ChatPage> {
//   late http.Client _client;
//   Uint8List? _imageBytes;
//   String _errorMessage = '';
//   bool _isLoading = false;
//   Timer? _timer;
//   // List<Face>? _faces = [];

//   // final FaceDetector _faceDetector = FaceDetector(
//   //   options: FaceDetectorOptions(
//   //     enableLandmarks: true,
//   //     enableClassification: true,
//   //     performanceMode: FaceDetectorMode.accurate,
//   //   ),
//   // );

//   @override
//   void initState() {
//     super.initState();
//     _initHttpClient();
//     _startImageFetching();
//   }

//   void _initHttpClient() {
//     final httpClient = HttpClient()
//       ..connectionTimeout = const Duration(seconds: 10)
//       ..autoUncompress = false;

//     _client = IOClient(httpClient);
//   }

//   // Future<void> _detectFacesFromBytes(Uint8List bytes) async {
//   //   try {
//   //     // Decode image (e.g., from JPEG or PNG)
//   //     final img.Image? decodedImage = img.decodeImage(bytes);
//   //     if (decodedImage == null) {
//   //       throw Exception('Failed to decode image');
//   //     }

//   //     // Convert to PNG (if needed)
//   //     final Uint8List pngBytes = img.encodePng(decodedImage);
//   //     // Use the original RGBA format directly
//   //     final inputImage = InputImage.fromBytes(
//   //       bytes: pngBytes, // Using the PNG bytes here
//   //       metadata: InputImageMetadata(
//   //         size: Size(
//   //             decodedImage.width.toDouble(), decodedImage.height.toDouble()),
//   //         rotation: InputImageRotation.rotation0deg,
//   //         format:
//   //             InputImageFormat.yuv420, // Use yuv420 for general image formats
//   //         bytesPerRow: decodedImage.width * 4,
//   //       ),
//   //     );

//   //     final faces = await _faceDetector.processImage(inputImage);

//   //     setState(() {
//   //       _faces = faces;
//   //     });
//   //   } catch (e) {
//   //     debugPrint("Error detecting faces: $e");
//   //   }
//   // }

//   Future<void> _fetchImage() async {
//     if (_isLoading) return;

//     setState(() {
//       _isLoading = true;
//       _errorMessage = '';
//       // _faces = [];
//     });

//     try {
//       final uri = Uri.parse('http://192.168.8.105/cap-image-hi.jpeg');
//       debugPrint('Fetching: $uri');

//       final response =
//           await _client.get(uri).timeout(const Duration(seconds: 15));

//       debugPrint('Status: ${response.statusCode}');
//       debugPrint('Content-Length: ${response.bodyBytes.length}');

//       if (response.statusCode == 200) {
//         // String extension = 'jpg';
//         // final contentType = response.headers['content-type'];
//         // if (contentType != null) {
//         //   if (contentType.contains('png')) {
//         //     extension = 'png';
//         //   } else if (contentType.contains('jpeg') ||
//         //       contentType.contains('jpg')) {
//         //     extension = 'jpg';
//         //   }
//         // }

//         // Save to a temporary file
//         final directory = await getTemporaryDirectory();
//         final file = File('${directory.path}/temp_image.$extension');
//         await file.writeAsBytes(response.bodyBytes);

//         // Create InputImage for ML Kit
//         final inputImage = InputImage.fromFilePath(file.path);

//         // Use the inputImage with Google ML Kit Face Detection
//         final faceDetector = GoogleMlKit.vision.faceDetector();
//         final faces = await faceDetector.processImage(inputImage);

//         // Update UI or handle detected faces
//         setState(() => _imageBytes = response.bodyBytes);
//         // Dispose the face detector when done
//         // faceDetector.close();

//         // setState(() {
//         //   _faces = faces;
//         // });
//       } else {
//         throw Exception('HTTP ${response.statusCode}');
//       }
//     } catch (e) {
//       setState(() => _errorMessage = 'Error: ${e.toString()}');
//       debugPrint('Fetch Error: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _startImageFetching() {
//     _fetchImage();
//     _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchImage());
//   }

//   @override
//   void dispose() {
//     _client.close();
//     _timer?.cancel();
//     // _faceDetector.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final User? user = FirebaseAuth.instance.currentUser;
//     final String? photoUrl = user?.photoURL;
//     final String? displayName = user?.displayName ?? 'Guest';

//     return Scaffold(
//       appBar: AppBar(title: const Text('Today')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 CircleAvatar(
//                   radius: 30,
//                   backgroundImage: photoUrl != null
//                       ? NetworkImage(photoUrl)
//                       : AssetImage('assets/default_profile.png')
//                           as ImageProvider,
//                 ),
//                 const SizedBox(width: 16),
//                 Text(
//                   'Hey\n${displayName ?? 'Unknown'}',
//                   style: const TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 24),
//             Expanded(child: _buildContent()),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _fetchImage,
//         child: const Icon(Icons.refresh),
//       ),
//     );
//   }

//   Widget _buildContent() {
//     if (_isLoading) return const Center(child: CircularProgressIndicator());
//     if (_errorMessage.isNotEmpty) return Center(child: Text(_errorMessage));
//     if (_imageBytes == null) return const Center(child: Text('No image'));

//     return SingleChildScrollView(
//       child: Column(
//         children: [
//           Image.memory(
//             _imageBytes!,
//             fit: BoxFit.contain,
//             gaplessPlayback: true,
//             width: double.infinity,
//             frameBuilder: (_, child, frame, __) => frame == null
//                 ? const Center(child: CircularProgressIndicator())
//                 : child,
//           ),
//           const SizedBox(height: 20),
//           // if (_faces != null && _faces!.isNotEmpty)
//           //   ..._faces!.map((face) => Padding(
//           //         padding: const EdgeInsets.all(8.0),
//           //         child: Column(
//           //           crossAxisAlignment: CrossAxisAlignment.start,
//           //           children: [
//           //             const Text(
//           //               'Face Detected!',
//           //               style: TextStyle(
//           //                 fontSize: 16,
//           //                 fontWeight: FontWeight.bold,
//           //               ),
//           //             ),
//           //             Text(
//           //                 'Smiling Probability: ${face.smilingProbability?.toStringAsFixed(2) ?? 'N/A'}'),
//           //             Text(
//           //                 'Left Eye Open Probability: ${face.leftEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A'}'),
//           //             Text(
//           //                 'Right Eye Open Probability: ${face.rightEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A'}'),
//           //           ],
//           //         ),
//           //       ))
//           // else
//           //   const Text('No faces detected.'),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
