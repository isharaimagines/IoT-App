import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:intl/intl.dart';
import 'package:iot_app/components/device_config_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late http.Client _client;
  Timer? _timer;
  String _isDeviceActive = 'Checking...';
  bool _isLoading = false;
  String deviceIPAddress = '';

  void _initHttpClient() {
    final httpClient = HttpClient();
    _client = IOClient(httpClient);
  }

  void _startGetStatus() {
    _timer?.cancel();
    _checkDeviceStatus();

    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _checkDeviceStatus();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkDeviceStatus() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      deviceIPAddress = prefs.getString('deviceIPAddress') ?? '192.168.45.13';
    });

    if (!mounted || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('http://$deviceIPAddress/status-100');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 60));

      if (mounted) {
        setState(() {
          _isDeviceActive = response.statusCode == 200 ? 'Online' : 'Offline';
        });
      }
    } on SocketException {
      if (mounted) setState(() => _isDeviceActive = 'Switch Off');
    } on TimeoutException {
      if (mounted) setState(() => _isDeviceActive = 'Timeout');
    } catch (e) {
      if (mounted) setState(() => _isDeviceActive = 'Error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor() {
    switch (_isDeviceActive) {
      case 'Online':
        return Colors.green;
      case 'Offline':
        return Colors.red;
      case 'Network Error':
      case 'Timeout':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _initHttpClient();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGetStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _isLoading = false;
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    String getImageForTag(String? tag) {
      switch (tag?.toLowerCase()) {
        case 'genuine happiness':
          return 'assets/bg_Card2.png';
        case 'moderate happiness':
          return 'assets/bg_Card1.png';
        case 'uncomfortable':
          return 'assets/bg_Card3.png';
        default:
          return 'assets/bg_Card4.png';
      }
    }

    Color getColorForTag(String? tag) {
      switch (tag?.toLowerCase()) {
        case 'genuine happiness':
          return Colors.yellow.shade100;
        case 'moderate happiness':
          return Colors.blue.shade50;
        case 'uncomfortable':
          return Colors.green.shade50;
        default:
          return Colors.blueGrey.shade50;
      }
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : const AssetImage('assets/unknown-icon.jpg')
                        as ImageProvider,
              ),
              title: Text(
                user?.displayName ?? 'Guest',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'How are you today?',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              child: Padding(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: AssetImage('assets/plant-100.png'),
                    radius: 30,
                  ),
                  title: const Text(
                    'MY SMART POT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _isDeviceActive,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeviceSetupPage(),
                            ),
                          ),
                          // borderRadius: BorderRadius.circular(2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 200, 230, 201),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (_isDeviceActive == 'Online' ||
                                          _isDeviceActive == 'Offline')
                                      ? 'Connected'
                                      : 'Connect',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Today Insight',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.normal),
            ),
            Expanded(
              child: user == null
                  ? const Center(
                      child: Text('Please sign in to view activities'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('recent')
                          .doc(user.uid)
                          .collection('activities')
                          .where('addtime',
                              isGreaterThanOrEqualTo:
                                  Timestamp.fromDate(startOfDay))
                          .where('addtime',
                              isLessThan: Timestamp.fromDate(endOfDay))
                          .orderBy('addtime', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                              child: Text('No activities today'));
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final doc = snapshot.data!.docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final time =
                                (data['addtime'] as Timestamp).toDate();

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: getColorForTag(data['tag']),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Opacity(
                                        opacity: 0.5,
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(8),
                                            bottomRight: Radius.circular(8),
                                          ),
                                          child: Image.asset(
                                            getImageForTag(data['tag']),
                                            fit: BoxFit.cover,
                                            width: 180,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat.jm().format(time),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['title'] ?? 'No Title',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(data['about'] ?? 'No Description'),
                                        const SizedBox(height: 6),
                                        if (data['tag'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF92E3A9),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              data['tag']
                                                  .toString()
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
