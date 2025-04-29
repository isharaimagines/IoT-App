import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
          ],
        ),
      ),
    );
  }

  // Widget _buildContent() {
  //   if (_isLoading) return const Center(child: CircularProgressIndicator());
  //   if (_errorMessage.isNotEmpty)
  //     return Center(child: Text(_errorMessage, textAlign: TextAlign.center));
  //   if (_imageBytes == null)
  //     return const Center(
  //         child: Text('Tap the refresh button to load an image.'));

  //   return Image.memory(
  //     _imageBytes!,
  //     fit: BoxFit.contain,
  //     gaplessPlayback: true,
  //     errorBuilder: (context, error, stackTrace) => Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         const Icon(Icons.error_outline, color: Colors.red, size: 48),
  //         const SizedBox(height: 8),
  //         Text('Failed to display image:\n$error', textAlign: TextAlign.center),
  //       ],
  //     ),
  //   );
  // }
}
