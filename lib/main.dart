import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iot_app/components/device_config_page.dart';
import 'package:iot_app/components/sign_in_page.dart';
import 'package:iot_app/page/chat_page.dart';
import 'package:iot_app/page/home_page.dart';
import 'package:iot_app/page/mood_page.dart';
import 'package:iot_app/page/profle_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Check if ESP32-CAM is configured
          return FutureBuilder<bool>(
            future: _isDeviceConfigured(),
            builder: (context, configSnapshot) {
              if (configSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }

              if (configSnapshot.data == true) {
                return MainPage();
              } else {
                return DeviceSetupPage();
                // return MainPage();
              }
            },
          );
        }

        return SignInPage();
      },
    );
  }

  Future<bool> _isDeviceConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('deviceConfigured') ?? false;
  }
}

// Your existing MainPage and _MainPageState classes remain the same
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int index = 0;

  final screens = [HomePage(), ChatPage(), MoodPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) => Scaffold(
      body: screens[index],
      bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
              indicatorColor: Colors.green.shade100,
              labelTextStyle: WidgetStateProperty.all(
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (index) =>
                  setState(() => this.index = index),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: "Today",
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat),
                  label: "Chat",
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: "Memories",
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: "Setting",
                ),
              ])));
}
