import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iot_app/components/device_config_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();

  Future<void> resetESP32() async {
    final url = Uri.parse('http://esp32.local/reset');

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

        await Future.delayed(const Duration(seconds: 1));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
