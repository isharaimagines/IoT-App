import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late http.Client _client;
  Timer? _timer;
  String _isDeviceActive = 'Offline';

  @override
  void initState() {
    super.initState();
    _initHttpClient();
    _startGetStatus();
  }

  void _initHttpClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..autoUncompress = false;

    _client = IOClient(httpClient);
  }

  void _startGetStatus() {
    _initDeviceStatus();
    _timer =
        Timer.periodic(const Duration(seconds: 60), (_) => _initDeviceStatus());
  }

  Future<void> _initDeviceStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedIp = prefs.getString('device_ip');

      if (storedIp == null || storedIp.isEmpty) {
        return;
      }

      final uri = Uri.parse('http://$storedIp/status-100');
      final response = await _client.get(uri);

      // Validate response
      if (response.statusCode != 200) {
        setState(() {
          _isDeviceActive = 'Offline';
        });
        return;
      } else {
        setState(() {
          _isDeviceActive = 'Active';
        });
        return;
      }

      // Face detection
    } on SocketException {
      setState(() {
        _isDeviceActive = 'Network Error';
      });
      rethrow;
    } on Exception {
      setState(() {
        _isDeviceActive = 'Error';
      });
      rethrow;
    } catch (e) {
      setState(() {
        _isDeviceActive = 'Unexpected Error';
      });
      rethrow;
    } finally {
      setState(() {
        _isDeviceActive = 'Not Loading...';
      });
    }
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
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    String getImageForTag(String? tag) {
      switch (tag) {
        case 'happy':
          return 'assets/bg_Card2.png';
        case 'sad':
          return 'assets/bg_Card1.png';
        case 'anger':
          return 'assets/bg_Card3.png';
        default:
          return 'assets/bg_Card4.png';
      }
    }

    Color getColorForTag(String? tag) {
      switch (tag) {
        case 'happy':
          return Colors.yellow.shade50;
        case 'sad':
          return Colors.blue.shade50;
        case 'anger':
          return Colors.red.shade50;
        default:
          return Colors.grey.shade50;
      }
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 18),
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
                'How are you today?',
                style: TextStyle(
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            SizedBox(height: 10),
            Card(
              child: Padding(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: AssetImage('assets/plant-100.png'),
                    radius: 28,
                  ),
                  title: const Text('IoT PotDevice'),
                  subtitle: Text(
                    _isDeviceActive,
                    style: TextStyle(
                      color: Colors.green.shade500,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Recent Activities',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
                // fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('recent')
                    .doc(user!.uid)
                    .collection('activities')
                    .where('addtime',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                    .where('addtime', isLessThan: Timestamp.fromDate(endOfDay))
                    .orderBy('addtime', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No activities found.'));
                  }

                  return ScrollConfiguration(
                      behavior: const ScrollBehavior()
                          .copyWith(physics: BouncingScrollPhysics()),
                      child: ListView(
                        children: snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            color: getColorForTag(data['tag']),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Opacity(
                                      opacity: 0.5,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.only(
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
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat.jm().format(
                                            (data['addtime'] as Timestamp)
                                                .toDate()),
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        data['title'] ?? 'No Title',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(data['about'] ?? 'No Description'),
                                      SizedBox(height: 6),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8.0, vertical: 2.0),
                                        decoration: BoxDecoration(
                                          color:
                                              Color.fromRGBO(146, 227, 169, 1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          data['tag'] ?? 'No Tag',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ));
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
