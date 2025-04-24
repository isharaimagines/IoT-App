import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:iot_app/main.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:http/http.dart' as http;

class DeviceSetupPage extends StatefulWidget {
  const DeviceSetupPage({super.key});

  @override
  _DeviceSetupPageState createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  bool _isConnectedToESP = false;
  bool _isChecking = false;
  bool _hasAutoNavigated = false; // Add this flag
  bool _obscurePassword = true;
  final NetworkInfo _networkInfo = NetworkInfo();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  List<WiFiAccessPoint> _availableNetworks = [];
  bool _isLoading = false;
  String? _selectedSSID;

  bool _isConnecting = false;
  String _status = "";

  Future<void> _checkPermissionsAndScan() async {
    setState(() => _isLoading = true);

    final status = await Permission.location.request();
    if (status.isGranted) {
      await _scanNetworks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Location permission is required to scan WiFi networks')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _scanNetworks() async {
    try {
      // Start scanning
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        throw Exception('Cannot scan: $canScan');
      }

      // Get scanned results
      final results = await WiFiScan.instance.getScannedResults();
      setState(() {
        _availableNetworks = results;
        if (_availableNetworks.isNotEmpty) {
          _selectedSSID = _availableNetworks.first.ssid;
          _ssidController.text = _selectedSSID!;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check WiFi and Location service.\n$e')),
      );
    }
  }

  Future<void> _sendWiFiCredentials() async {
    final ssid = _ssidController.text.trim();
    final password = _passController.text.trim();
    final url = Uri.parse('http://192.168.4.1/config');

    setState(() => _isChecking = true);
    try {
      final wifiName = await _networkInfo.getWifiName();
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnectedToESP = wifiName == '"ESP32-CAM-SETUP"';
        _isChecking = false;
      });

      // Auto-navigate if connected
      if (_isConnectedToESP && !_isChecking && mounted) {
        _hasAutoNavigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainPage(),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking WiFi: ${e.message}')),
      );

      return;
    }

    if (ssid.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both SSID and password.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configuring IoT Device...')),
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'ssid': ssid, 'password': password},
      );

      if (response.statusCode == 200) {
        // Mark device as configured
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('deviceConfigured', true);

        setState(() {
          _isConnecting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configuring! IoT Device will reboot.')),
        );
        _isConnecting = true;
      } else {
        setState(() {
          _status = "ESP32 error: ${response.body}";
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send config: $e')),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect IoT Device')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Connection Instructions
                    const Text(
                      '1. Let\'s connect the IoT device',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    _buildStep(
                      number: 1,
                      text: 'Please turn on Wi-Fi on your phone',
                    ),
                    const SizedBox(height: 16),
                    _buildStep(
                      number: 2,
                      text: 'Select & connect to:',
                      subText: 'SSID: ESP32-CAM-SETUP\nPassword: 123456789',
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.wifi),
                        label: const Text('Open Wi-Fi Settings'),
                        onPressed: () {
                          AppSettings.openAppSettings(
                              type: AppSettingsType.wifi);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Section 2: WiFi Configuration
                    const Text(
                      '2. Select your public WiFi network',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // WiFi Selection Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSSID,
                            decoration: const InputDecoration(
                              labelText: 'Select WiFi Network',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            items: _availableNetworks
                                .map((network) => DropdownMenuItem(
                                      value: network.ssid,
                                      child: Text(network.ssid),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSSID = value;
                                _ssidController.text = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed:
                              _isLoading ? null : _checkPermissionsAndScan,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    TextField(
                      controller: _passController,
                      decoration: InputDecoration(
                        labelText: "Your WiFi Password",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: 20),

                    // Config Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sendWiFiCredentials,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text("Config IoT Device"),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Loading Indicator
                    if (_isChecking)
                      const Center(child: CircularProgressIndicator()),

                    // Spacer replacement for small screens
                    SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep(
      {required int number, required String text, String? subText}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            number.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 16)),
              if (subText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    subText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
