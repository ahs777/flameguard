import 'dart:async';
import 'dart:ui';

//Import dependencies
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// Import your screens and services
import 'screens/bluetooth_screen.dart';
import 'screens/call_screen.dart';
import 'screens/home_screen.dart';
import 'screens/voice_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'screens/bluetooth_service.dart';
import 'screens/app_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the background service
  await initializeBackgroundService();

  // Create an instance of the FlutterLocalNotificationsPlugin
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await notificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final bluetoothService = BluetoothService();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Initialize Bluetooth service
    await bluetoothService.initialize();

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (service is AndroidServiceInstance) {
        bool isConnected = await bluetoothService.isDeviceConnected(
            bluetoothService.connectedDevice ?? BluetoothDevice(address: ''));
        String statusMessage = isConnected
            ? "Connected to ${bluetoothService.connectedDevice?.name ?? 'Unknown Device'}"
            : "No device connected or Bluetooth is turned off";

        service.setForegroundNotificationInfo(
          title: "Flame Guard",
          content: statusMessage,
        );
      }

      service.invoke(
        'update',
        {
          "current_date": DateTime.now().toIso8601String(),
        },
      );
    });
  }
}

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  // iOS specific background task code can be added here
  return true;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<bool> _isDarkThemeNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final theme = await getTheme();
    setState(() {
      _isDarkThemeNotifier.value = theme == 'dark';
    });
  }

  Future<void> _toggleTheme() async {
    final isDarkTheme = !_isDarkThemeNotifier.value;
    _isDarkThemeNotifier.value = isDarkTheme;
    await saveTheme(isDarkTheme ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDarkThemeNotifier,
      builder: (context, isDarkTheme, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Flutter Demo',
          theme: isDarkTheme
              ? ThemeData.dark().copyWith(
                  useMaterial3: true,
                  drawerTheme: DrawerThemeData(
                    backgroundColor: Colors.black,
                    scrimColor: Colors.black.withOpacity(0.5),
                  ),
                  scaffoldBackgroundColor: Colors.black,
                  textTheme: const TextTheme(
                    titleLarge: TextStyle(color: Colors.white),
                    bodyLarge: TextStyle(color: Colors.white),
                    bodyMedium: TextStyle(color: Colors.white),
                    bodySmall: TextStyle(color: Colors.white),
                  ),
                )
              : ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
                  useMaterial3: true,
                  drawerTheme: DrawerThemeData(
                    backgroundColor: Colors.white,
                    scrimColor: Colors.black.withOpacity(0.2),
                  ),
                  scaffoldBackgroundColor: Colors.white,
                  textTheme: const TextTheme(
                    titleLarge: TextStyle(color: Colors.black),
                    bodyLarge: TextStyle(color: Colors.black),
                    bodyMedium: TextStyle(color: Colors.black),
                    bodySmall: TextStyle(color: Colors.black),
                  ),
                ),
          home: MyHomePage(
            title: 'Flame Guard',
            onThemeToggle: _toggleTheme,
            isDarkThemeNotifier: _isDarkThemeNotifier,
          ),
        );
      },
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.onThemeToggle,
    required this.isDarkThemeNotifier,
  });

  final String title;
  final VoidCallback onThemeToggle;
  final ValueNotifier<bool> isDarkThemeNotifier;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final BluetoothService _bluetoothService = BluetoothService(); // Initialize BluetoothService

  @override
  void initState() {
    super.initState();
    _initializeBluetoothService();
  }

  Future<void> _initializeBluetoothService() async {
    await _bluetoothService.initialize();
    _bluetoothService.loadSavedDevice(); // Load saved Bluetooth device on startup
  }

  void _onItemTapped(int index) {
    if (index < 4) { // Ensure index is within bounds for BottomNavigationBar
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showBluetoothScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BluetoothScreen(
        ),
      ),
    // );
    // showModalBottomSheet(
    //   context: context,
    //   isScrollControlled: true, // Allow full height BottomSheet
    //   builder: (BuildContext context) {
    //     return SizedBox(
    //       height: MediaQuery.of(context).size.height * 0.8, // Adjust height as needed
    //       child: const BluetoothScreen(), // Display BluetoothScreen
    //     );
    //   },
     );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850] // Dark grey background for dark theme
            : Color(0xFFFEB976), // Orange background for light theme
        title: Text(
          widget.title,
          style: Theme.of(context).brightness == Brightness.dark
              ? const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold) // OrangeAccent text color for dark theme
              : Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black), // Black text color for light theme
        ),
        actions: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: widget.isDarkThemeNotifier,
            builder: (context, isDarkTheme, _) {
              return IconButton(
                icon: Icon(
                  isDarkTheme
                      ? Icons.brightness_7 // Light theme icon
                      : Icons.brightness_2, // Dark theme icon
                  color: isDarkTheme
                      ? Colors.white
                      : Colors.black, // Set icon color based on theme
                ),
                onPressed: widget.onThemeToggle,
              );
            },
          ),
          StreamBuilder<BluetoothDevice?>(
            stream: _bluetoothService.connectedDeviceStream,
            builder: (context, snapshot) {
              BluetoothDevice? connectedDevice = snapshot.data;
              return IconButton(
                icon: Icon(
                  connectedDevice != null
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: connectedDevice != null ? Colors.blue : Colors.red,
                ),
                onPressed: _showBluetoothScreen, // Show Bluetooth screen
              );
            },
          ),
        ],
      ),
      body: _selectedIndex == 4
          ? Center(child: Text("Bluetooth Screen Placeholder")) // Display a placeholder for the Bluetooth screen in the body
          : [
              const HomeScreen(),
              const CallScreen(),
              const VoiceScreen(),
              const SettingsScreen(),
            ][_selectedIndex], // Display selected BottomNavigationBar page
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.orangeAccent
            : Colors.orange,
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.voice_chat),
            label: 'Voice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          // Optional: Add Bluetooth as an item but handle its visibility differently
        ],
      ),
    );
  }
}
