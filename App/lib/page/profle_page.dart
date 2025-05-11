import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:iot_app/components/device_config_page.dart';
import 'package:iot_app/main.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  late http.Client _client;

  bool light = false;

  @override
  void initState() {
    super.initState();
    _initHttpClient();
  }

  void _initHttpClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..autoUncompress = false;

    _client = IOClient(httpClient);
  }

  Future<void> _resetESP32() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();
    final storedIp = prefs.getString('device_ip');

    if (storedIp == null || storedIp.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6), // Dialog border radius
        ),
        title: const Text("Confirm Reset"),
        content: const Text(
            "This will erase all device configurations. Reset the smart pot. Are you sure you want to continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Reset Anyway"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final loadingSnackBar = SnackBar(
          backgroundColor: Colors.black,
          content: Row(
            children: [
              const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
              const SizedBox(width: 16),
              Text(
                'Initiating reset...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        );
        scaffoldMessenger.showSnackBar(loadingSnackBar);

        final uri = Uri.parse('http://$storedIp/reset-440');
        final response =
            await _client.get(uri).timeout(const Duration(seconds: 5));

        scaffoldMessenger.hideCurrentSnackBar();

        if (response.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('deviceConfigured', false);

          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Device reset successful'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(seconds: 1));
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DeviceSetupPage(),
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Reset failed: ${response.statusCode}',
                  style: TextStyle(color: Colors.black)),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Reseting failed. Please device connect to the Internet to continue.${error}')),
        );
        return;
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6), // Dialog border radius
        ),
        title: const Text("Sign Out"),
        content: const Text("Do you need sign out from WellSync"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Sign Out"),
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

  Future<void> _accountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6), // Dialog border radius
        ),
        title: const Text("Delete Account"),
        content: const Text(
            "This will delete account. Are you sure you want to continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
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
    final User? user = FirebaseAuth.instance.currentUser;
    final String? photoUrl = user?.photoURL;
    final String? emailId = user?.email;
    final String? displayName = user?.displayName;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 18),
              Text(
                'Your Account',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 0),
                leading: CircleAvatar(
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : AssetImage('assets/unknown-icon.jpg') as ImageProvider,
                ),
                title: Text(
                  displayName ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  emailId ?? '',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Notification Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Real time notification',
                      style: TextStyle(fontSize: 18)),
                  Switch(
                    value: light,
                    activeColor: Colors.green,
                    onChanged: (bool value) {
                      setState(() {
                        light = value;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 18),
              Text(
                'Account Manage & Security',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    onPressed: () async {
                      await _accountDeletion();
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Account Permanently')),
              ),
              const SizedBox(
                height: 10,
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    onPressed: () async {
                      await _confirmLogout();
                    },
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Sign Out')),
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                'Smart Pot Manage',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    onPressed: () async {
                      await _resetESP32();
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset Smart Pot')),
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
