import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:multicast_dns/multicast_dns.dart';

class MDNSDiscovery {
  final MDnsClient _mdnsClient = MDnsClient();

  Future<String?> discoverESP32IP(String serviceName) async {
    try {
      await _mdnsClient.start();

      // Search for the service
      await for (final PtrResourceRecord ptr
          in _mdnsClient.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceName),
      )) {
        // Get SRV record for service
        await for (final SrvResourceRecord srv
            in _mdnsClient.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          // Get IP address from A records
          await for (final IPAddressResourceRecord ip
              in _mdnsClient.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            _mdnsClient.stop();
            return ip.address.address; // Return IP address
          }
        }
      }

      _mdnsClient.stop();
      return null; // Not found
    } catch (e) {
      _mdnsClient.stop();
      return null;
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late http.Client _client;
  Uint8List? _imageBytes;
  String _errorMessage = '';
  bool _isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initHttpClient();
    _startImageFetching();
  }

  void _initHttpClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..autoUncompress = false;

    _client = IOClient(httpClient);
  }

  Future<void> _fetchImage() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final uri = Uri.parse(
          'http://192.168.8.105/capture?t=${DateTime.now().millisecondsSinceEpoch}');
      debugPrint('Fetching: $uri');

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));

      debugPrint('Status: ${response.statusCode}');
      debugPrint('Content-Length: ${response.bodyBytes.length}');

      if (response.statusCode == 200) {
        setState(() => _imageBytes = response.bodyBytes);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }

      final discovery = MDNSDiscovery();
      final ip = await discovery.discoverESP32IP('_esp32service._tcp.local');

      if (ip != null) {
        debugPrint('Found ESP32 IP: $ip');
      } else {
        debugPrint('ESP32 not found.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
      debugPrint('Fetch Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startImageFetching() {
    _fetchImage();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchImage());
  }

  @override
  void dispose() {
    _client.close();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESP32-CAM Feed')),
      body: _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchImage,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty) return Center(child: Text(_errorMessage));
    if (_imageBytes == null) return const Center(child: Text('No image'));

    return Image.memory(
      _imageBytes!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (_, child, frame, __) => frame == null
          ? const Center(child: CircularProgressIndicator())
          : child,
    );
  }
}
