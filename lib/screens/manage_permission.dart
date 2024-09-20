import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ManagePermissionsScreen extends StatefulWidget {
  const ManagePermissionsScreen({Key? key}) : super(key: key);

  @override
  _ManagePermissionsScreenState createState() => _ManagePermissionsScreenState();
}

class _ManagePermissionsScreenState extends State<ManagePermissionsScreen> {
  Map<Permission, bool> _permissionsStatus = {};

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.contacts,
      Permission.microphone,
      Permission.storage,
      Permission.phone,
      Permission.sms,
      Permission.camera,
      Permission.calendar,
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
      _openAppSettingsDialog(permission);
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    await permission.request();
    bool isGranted = await permission.isGranted;
    setState(() {
      _permissionsStatus[permission] = isGranted;
    });
  }

  Future<void> _openAppSettingsDialog(Permission permission) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text(
          'To deny this permission, you need to go to the app settings and manually revoke it. Would you like to open the settings now?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Permissions'),
        backgroundColor: isDarkTheme ? Colors.grey[850] : Colors.orangeAccent,
        titleTextStyle: TextStyle(
          color: isDarkTheme ? Colors.orange : Colors.black,
          fontSize: 20.0,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildPermissionToggle(
            'Bluetooth',
            Permission.bluetooth,
            Icons.bluetooth,
          ),
          _buildPermissionToggle(
            'Location',
            Permission.location,
            Icons.location_on,
          ),
          _buildPermissionToggle(
            'Bluetooth Scan',
            Permission.bluetoothScan,
            Icons.bluetooth_searching,
          ),
          _buildPermissionToggle(
            'Bluetooth Connect',
            Permission.bluetoothConnect,
            Icons.bluetooth_connected,
          ),
          _buildPermissionToggle(
            'Contacts',
            Permission.contacts,
            Icons.contacts,
          ),
          _buildPermissionToggle(
            'Microphone',
            Permission.microphone,
            Icons.mic,
          ),
          _buildPermissionToggle(
            'Storage',
            Permission.storage,
            Icons.storage,
          ),
          _buildPermissionToggle(
            'Phone',
            Permission.phone,
            Icons.phone,
          ),
          _buildPermissionToggle(
            'SMS',
            Permission.sms,
            Icons.sms,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionToggle(String title, Permission permission, IconData icon) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      color: isDarkTheme ? Colors.grey[800] : Colors.white,
      child: ListTile(
        leading: Icon(icon, color: isDarkTheme ? Colors.orange : Colors.orangeAccent),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkTheme ? Colors.white : Colors.black,
          ),
        ),
        trailing: Switch(
          value: _permissionsStatus[permission] ?? false,
          onChanged: (value) => _handlePermissionToggle(permission, value),
          activeColor: Colors.blue,
        ),
      ),
    );
  }
}
