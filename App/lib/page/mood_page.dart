import 'package:flutter/material.dart';

class MoodPage extends StatelessWidget {
  const MoodPage({super.key}); // Recommended for stateless widgets

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Explicitly return the Scaffold
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
            ""), // const for better performance if the text is static
      ),
      body: const Center(
        // const if the content is static
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 48), // const here as well
          child: const Text('Mood'), // and here
        ),
      ),
    );
  }
}
