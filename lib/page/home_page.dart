import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:iot_app/components/device_config_page.dart';
import 'package:iot_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String _status = "";

  Future<void> resetESP32() async {
    setState(() => _status = "Sending reset...");
    final url = Uri.parse('http://192.168.8.105/rest');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('deviceConfigured', false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuring. Rebooting IoT...'),
            duration: Duration(seconds: 2), // Show for 2 seconds
          ),
        );

        await Future.delayed(const Duration(seconds: 2));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DeviceSetupPage(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking status: $e')),
      );
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);

      await Future.delayed(Duration(seconds: 2));

      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MyApp(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ESP32-CAM WiFi Setup"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: resetESP32,
                child: const Text("Reset IoT Device (Clear EEPROM)"),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
