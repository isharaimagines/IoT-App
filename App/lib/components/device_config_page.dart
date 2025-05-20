import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/io_client.dart';
import 'package:app_settings/app_settings.dart';
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
  final _isChecking = false;
  bool _obscurePassword = true;
  final NetworkInfo _networkInfo = NetworkInfo();
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  final _ipNetController = TextEditingController();
  List<WiFiAccessPoint> _availableNetworks = [];
  bool _isLoading = false;
  String? _selectedSSID;
  late http.Client _client;
  String idToken = "";

  Future<void> _checkPermissionsAndScan() async {
    setState(() => _isLoading = true);

    final status = await Permission.location.request();
    if (status.isGranted) {
      await _scanNetworks();
    } else {
      Fluttertoast.showToast(
        msg: "Location permission is required to scan WiFi networks",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _scanNetworks() async {
    try {
      // Start scanning
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        Fluttertoast.showToast(
          msg: "Cannot scan: $canScan",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
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
      Fluttertoast.showToast(
        msg: "Check WiFi and Location service.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _initidTokens() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(
        msg: "User not authenticated",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() async => idToken = (await user.getIdToken())!);
  }

  Future<void> _initHttpClient() async {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..autoUncompress = false;

    _client = IOClient(httpClient);
  }

  Future<void> _sendWiFiCredentials() async {
    final ssid = _ssidController.text.trim();
    final password = _passController.text.trim();
    final encodedSsid = Uri.encodeComponent(ssid);
    final encodedPassword = Uri.encodeComponent(password);

    // Get current user UID
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(
        msg: "User not authenticated",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    final uid = user.uid;
    final encodedUid = Uri.encodeComponent(uid);

    final encodedidToken = Uri.encodeComponent(idToken);

    debugPrint(idToken);
    debugPrint(encodedidToken);

    if (ssid.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter both SSID and password.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    try {
      // Verify we're still connected to ESP32 network
      final wifiName = await _networkInfo.getWifiName();
      final isConnected = wifiName?.replaceAll('"', '') == 'ESP32-CAM-SETUP';

      if (!mounted) return;
      if (!isConnected) {
        Fluttertoast.showToast(
          msg: "Not connected to ESP32-CAM-SETUP network",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Errorz: ${e.toString()}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }

    try {
      final uri = Uri.parse(
          'http://192.168.4.1/config-100?ssid=$encodedSsid&password=$encodedPassword&useruid=$encodedUid&idtoken=$encodedidToken');
      final response = await _client.get(uri);

      // Validate response
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('Invalid image response');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('deviceConfigured', true);

      Fluttertoast.showToast(
        msg: "Configured...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainPage(),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Errors",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _checkIPNetwork() async {
    final ipNet = _ipNetController.text.trim();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('deviceIPAddress', ipNet);
    Fluttertoast.showToast(
      msg: "Saved",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  Future<void> _loadDeviceIPAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIP = prefs.getString('deviceIPAddress') ?? '';
    _ipNetController.text = storedIP;
  }

  @override
  void initState() {
    super.initState();
    _initHttpClient();
    _initidTokens();
    _loadDeviceIPAddress();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    _ipNetController.dispose();
    super.dispose();
  }

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

                    SizedBox(
                      width: double.maxFinite,
                      child: ElevatedButton.icon(
                        label: const Text(
                          'Open Wi-Fi Settings',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () {
                          AppSettings.openAppSettings(
                              type: AppSettingsType.wifi);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(200, 230, 201, 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          foregroundColor: Colors.black,
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
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(100)),
                              ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh,
                                  color: Colors.black,
                                ),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                              side: const BorderSide(color: Colors.black),
                            ),
                            padding: const EdgeInsets.all(14),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                        ),
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
                    const SizedBox(height: 12),

                    // Config Button
                    SizedBox(
                      width: double.maxFinite,
                      child: ElevatedButton(
                        onPressed: _sendWiFiCredentials,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(200, 230, 201, 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          "Configure Device",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 3: IP Network Configure
                    const Text(
                      '3. Select your IP Address',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: _ipNetController,
                      decoration: InputDecoration(
                        labelText: "Device IP Address",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.maxFinite,
                      child: ElevatedButton(
                        onPressed: _checkIPNetwork,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(200, 230, 201, 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          "Save",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),

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
          backgroundColor: Color.fromARGB(255, 200, 230, 201),
          child: Text(
            number.toString(),
            style: const TextStyle(color: Colors.black, fontSize: 12),
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
