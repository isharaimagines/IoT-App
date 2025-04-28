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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
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
          return const LoadingScreen();
        }

        if (snapshot.hasData) {
          return FutureBuilder<bool>(
            future: _isDeviceConfigured(),
            builder: (context, configSnapshot) {
              if (configSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }
              return configSnapshot.data == true
                  ? const MainPage()
                  : const DeviceSetupPage();
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

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  static const _navBarTheme = NavigationBarThemeData(
    indicatorColor: Color.fromARGB(255, 200, 230, 201),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
  );

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today),
      label: 'Today',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat),
      label: 'Chat',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: 'Memories',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  final List<Widget> _screens = [
    const HomePage(),
    ChatPage(),
    MoodPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: _navBarTheme,
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: _destinations,
        ),
      ),
    );
  }
}
