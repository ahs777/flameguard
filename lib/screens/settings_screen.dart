import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'manage_permission.dart'; // Import your ManagePermissionsScreen
import 'test_system_screen.dart'; // Import your TestSystemScreen
import 'bluetooth_service.dart'; // Import your BluetoothService
import 'about_screen.dart'; // Import your AboutScreen

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<Permission, bool> _permissionsStatus = {};

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.contacts,
      Permission.microphone,
      Permission.storage,
    ];

    for (var permission in permissions) {
      bool isGranted = await permission.isGranted;
      setState(() {
        _permissionsStatus[permission] = isGranted;
      });
    }
  }

  Future<void> _handlePermissionToggle(Permission permission, bool value) async {
    if (value) {
      await _requestPermission(permission);
    } else {
      _openAppSettingsDialog();
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    await permission.request();
    bool isGranted = await permission.isGranted;
    setState(() {
      _permissionsStatus[permission] = isGranted;
    });
  }

  Future<void> _openAppSettingsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('To disable this permission, please go to the app settings and manually revoke it.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFactoryReset() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory Reset'),
        content: const Text('Are you sure you want to reset all settings and clear storage? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      await _performFactoryReset();
    }
  }

  Future<void> _performFactoryReset() async {
    // Clear all data in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Disconnect any connected Bluetooth device
    final bluetoothService = BluetoothService();
    await bluetoothService.disconnectFromDevice();

    // Optionally, you could navigate the user away from the screen or show a confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Factory reset successful.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Existing menu options
          _buildMenuOption('Manage Permissions', Icons.shield, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ManagePermissionsScreen()),
            );
          }),
          const SizedBox(height: 16),
          _buildMenuOption('Test System', Icons.build, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TestSystemScreen()),
            );
          }),
          const SizedBox(height: 16),
          _buildMenuOption('Factory Reset', Icons.restart_alt_rounded, onTap: _confirmFactoryReset),

          // Add the card to navigate to AboutScreen at the bottom
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              leading: const Icon(Icons.info, color: Colors.orange),
              title: const Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(String title, IconData icon, {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }
}
