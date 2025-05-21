import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:iot_app/components/device_config_page.dart';
import 'package:iot_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  late http.Client _client;
  bool light = false;
  bool _isResetting = false;
  bool _isLoggingOut = false;
  bool _isDeleting = false;
  String deviceIPAddress = '';

  void _initHttpClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback =
          (cert, host, port) => true; // For development only
    _client = IOClient(httpClient);
  }

  Future<void> _loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      light = prefs.getBool('notificationsEnabled') ?? false;
    });
  }

  Future<void> _saveNotificationPrefs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
  }

  Future<void> _resetESP32() async {
    if (_isResetting) return;
    setState(() => _isResetting = true);

    final navigator = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      deviceIPAddress = prefs.getString('deviceIPAddress') ?? '192.168.45.13';
    });

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text("Confirm Reset"),
          content: const Text(
              "This will erase all device configurations. Are you sure?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: const BorderSide(color: Colors.black),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Reset",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      Fluttertoast.showToast(
        msg: "Resetting device...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      final uri = Uri.parse('http://$deviceIPAddress/reset-440');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Not reset device');
      }

      await prefs.setBool('deviceConfigured', false);
      await prefs.remove('device_ip');

      Fluttertoast.showToast(
        msg: "Device reset successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const DeviceSetupPage()),
      );
    } on TimeoutException {
      SnackBar(content: Text('Reset timed out'));
    } catch (e) {
      SnackBar(content: Text('Reset failed: ${e.toString()}'));
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text("Sign Out"),
          content: const Text("Are you sure you want to sign out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: const BorderSide(color: Colors.black),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Sign Out",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('device_ip');

      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Logout failed",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _accountDeletion() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text("Delete Account"),
          content: const Text("This will permanently delete your account."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: const BorderSide(color: Colors.black),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Delete",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await _googleSignIn.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Deletion failed",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _showIntervalDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final TextEditingController controller = TextEditingController(
      text: (prefs.getInt('fetchIntervalSeconds')).toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Smart Pot Interval'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Interval (seconds)',
            hintText: 'Enter time in seconds',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();

              final seconds = int.tryParse(controller.text) ?? 20;
              await prefs.setInt('fetchIntervalSeconds', seconds);

              Navigator.pop(context);
              // Restart timer with new duration
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initHttpClient();
    _loadNotificationPrefs();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Your Account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : const AssetImage('assets/unknown-icon.jpg')
                        as ImageProvider,
              ),
              title: Text(
                user?.displayName ?? 'Unknown',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(user?.email ?? ''),
            ),
            const SizedBox(height: 24),
            const Text(
              'Notification Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text(
                'Real-time notifications',
                style: TextStyle(color: Colors.black), // Text color
              ),
              value: light,
              onChanged: (value) {
                setState(() => light = value);
                _saveNotificationPrefs(value);
              },
              activeColor: Colors.green, // Thumb when ON
              activeTrackColor:
                  Color.fromARGB(255, 200, 230, 201), // Track when ON
              inactiveThumbColor: Colors.grey, // Thumb when OFF
              inactiveTrackColor: Colors.white, // Track when OFF
            ),
            const SizedBox(height: 24),
            const Text(
              'Account Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              icon: Icons.delete,
              label: 'Delete Account',
              onPressed: _accountDeletion,
              isLoading: _isDeleting,
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              icon: Icons.logout,
              label: 'Sign Out',
              onPressed: _confirmLogout,
              isLoading: _isLoggingOut,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            const Text(
              'Device Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              icon: Icons.restart_alt,
              label: 'Reset Smart Pot',
              onPressed: _resetESP32,
              isLoading: _isResetting,
              color: Colors.black,
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              icon: Icons.restart_alt,
              label: 'Set Smart Pot Interval',
              onPressed: _showIntervalDialog,
              isLoading: _isResetting,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    required Color color,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      onPressed: isLoading ? null : onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: Colors.black,
        ),
      ),
    );
  }
}
