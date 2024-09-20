import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

// Save recordings
Future<void> saveRecordings(String jsonData) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('recordings', jsonData);
}

// Get recordings
Future<String?> getRecordings() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('recordings');
}

// Save state
Future<void> saveSetState(int index, bool isSet) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool('set_state_$index', isSet);
}

// Get state
Future<bool> getSetState(int index) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool('set_state_$index') ?? false;
}

// Save contacts
Future<void> saveContacts(List<Map<String, String>> contacts) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String jsonData = json.encode(contacts);
  await prefs.setString('contacts', jsonData);
}

// Load contacts
Future<List<Map<String, String>>> loadContacts() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? jsonData = prefs.getString('contacts');
  if (jsonData != null) {
    final List<dynamic> list = json.decode(jsonData);
    return list.map((e) => Map<String, String>.from(e)).toList();
  }
  return [];
}

// Save theme
Future<void> saveTheme(String theme) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme', theme);
}

// Get theme
Future<String?> getTheme() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('theme');
}

// Save connected Bluetooth device
Future<void> saveConnectedDevice(BluetoothDevice? device) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (device != null) {
    await prefs.setString('connected_device_address', device.address);
  } else {
    await prefs.remove('connected_device_address');
  }
}

// Get connected Bluetooth device
Future<BluetoothDevice?> getConnectedDevice() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? address = prefs.getString('connected_device_address');
  if (address != null) {
    List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
    try {
      return bondedDevices.firstWhere((device) => device.address == address);
    } catch (e) {
      return null; // Explicitly return null if the device is not found
    }
  }
  return null;
}
