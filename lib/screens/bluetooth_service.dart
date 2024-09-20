import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  BluetoothDevice? _connectedDevice;
  BluetoothConnection? _connection;
  final StreamController<BluetoothDevice?> _deviceStreamController = StreamController<BluetoothDevice?>.broadcast();
  final StreamController<List<BluetoothDevice>> _deviceListStreamController = StreamController<List<BluetoothDevice>>.broadcast();
  final StreamController<List<int>> _connectionStreamController = StreamController<List<int>>.broadcast();

  Stream<BluetoothDevice?> get connectedDeviceStream => _deviceStreamController.stream;
  Stream<List<BluetoothDevice>> get deviceListStream => _deviceListStreamController.stream;
  Stream<List<int>> get connectionStream => _connectionStreamController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<void> initialize() async {
    await refreshDeviceList();
    await loadSavedDevice();

    FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      if (state == BluetoothState.STATE_OFF) {
        _handleBluetoothTurnedOff();
      } else if (state == BluetoothState.STATE_ON) {
        refreshDeviceList();
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_connection != null && _connectedDevice == device) {
      return; // Already connected
    }

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _connectedDevice = device;
      _deviceStreamController.add(_connectedDevice);
      await _saveDevice(device);

      _connection?.input?.listen((data) {
        _connectionStreamController.add(data);
      })?.onDone(() {
        _handleDisconnected();
      });
    } catch (e) {
      print('Failed to connect: $e');
      _handleDisconnected();
    }
  }

  Future<void> disconnectFromDevice() async {
    if (_connection != null) {
      try {
        await _connection?.close();
        await _removeSavedDevice();
        _handleDisconnected();
      } catch (e) {
        print('Failed to disconnect: $e');
        _handleDisconnected();
      }
    }
  }

  Future<void> sendData(Uint8List data) async {
    if (_connection != null) {
      try {
        _connection!.output.add(data);
        await _connection!.output.allSent;
        print('Data sent successfully');
      } catch (e) {
        print('Failed to send data: $e');
      }
    } else {
      print('No device connected');
    }
  }

  Future<bool> isDeviceConnected(BluetoothDevice device) async {
    if (_connection != null && _connectedDevice == device) {
      try {
        await _connection!.output.allSent;
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Future<String?> readData() async {
    Completer<String?> completer = Completer<String?>();

    List<int> buffer = [];
    StreamSubscription<List<int>>? subscription;

    // Listen to the data stream from the connection
    subscription = connectionStream.listen((data) {
      buffer.addAll(data);

      // Check if we have received a newline character, indicating the end of a message
      if (buffer.contains(10)) { // 10 is the newline character '\n'
        subscription?.cancel(); // Safely cancel the subscription if it's not null

        // Convert the buffer to a string and split by newlines
        String receivedData = String.fromCharCodes(buffer);
        buffer.clear(); // Clear the buffer for future reads

        // Complete the completer with the received data
        completer.complete(receivedData.trim());
      }
    });

    // Timeout after 10 seconds if no data is received
    Future.delayed(Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        subscription?.cancel(); // Safely cancel the subscription if it's not null
        completer.complete(null); // Return null if timeout occurs
      }
    });

    return completer.future;
  }

  void _handleDisconnected() {
    _connectedDevice = null;
    _connection = null;
    _deviceStreamController.add(null);
    refreshDeviceList();
  }

  Future<void> _saveDevice(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connected_device_address', device.address);
  }

  Future<void> _removeSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('connected_device_address');
  }

  Future<void> loadSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedAddress = prefs.getString('connected_device_address');
    if (savedAddress != null) {
      BluetoothDevice? device = await _retrieveDeviceFromAddress(savedAddress);
      if (device != null) {
        _connectedDevice = device;
        _deviceStreamController.add(_connectedDevice);
        connectToDevice(device);
      }
    }
  }

  Future<BluetoothDevice?> _retrieveDeviceFromAddress(String address) async {
    List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    try {
      return devices.firstWhere((device) => device.address == address);
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshDeviceList() async {
    List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
    _deviceListStreamController.add(bondedDevices);
  }

  void _handleBluetoothTurnedOff() {
    _connectedDevice = null;
    _connection = null;
    _deviceStreamController.add(null);
    _deviceListStreamController.add([]);
  }

  Future<void> dispose() async {
    await _deviceStreamController.close();
    await _deviceListStreamController.close();
    await _connectionStreamController.close();
  }
}
