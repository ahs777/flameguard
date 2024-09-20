import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_service.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({Key? key}) : super(key: key);

  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> with WidgetsBindingObserver {
  final BluetoothService _bluetoothService = BluetoothService();
  List<BluetoothDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeBluetooth();

    _bluetoothService.deviceListStream.listen((devices) {
      setState(() {
        _devices = devices;
      });
    });

    FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      if (state == BluetoothState.STATE_ON) {
        _initializeBluetooth();
      } else if (state == BluetoothState.STATE_OFF) {
        setState(() {
          _devices.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeBluetooth();
    }
  }

  Future<void> _initializeBluetooth() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();

    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.location.isGranted) {
      BluetoothState state = await FlutterBluetoothSerial.instance.state;
      if (state == BluetoothState.STATE_OFF) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bluetooth is turned off'),
        ));
        return;
      }

      if (_bluetoothService.connectedDevice == null) {
        await _bluetoothService.initialize();
      }
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Permissions not granted'),
      ));
    }
  }

  Future<void> _refreshDeviceList() async {
    if (await FlutterBluetoothSerial.instance.state == BluetoothState.STATE_ON) {
      await _bluetoothService.refreshDeviceList();
    } else {
      setState(() {
        _devices.clear();
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await _bluetoothService.connectToDevice(device);
    await _refreshDeviceList();
  }

  Future<void> _disconnectFromDevice() async {
    await _bluetoothService.disconnectFromDevice();
    await _refreshDeviceList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Bluetooth Devices',
          style: TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDarkTheme ? Colors.white : Colors.black),
            onPressed: _refreshDeviceList,
          ),
        ],
      ),
      body: Container(
        color: isDarkTheme ? Colors.black : Colors.white,
        child: ListView(
          children: _devices.map((device) {
            return StreamBuilder<BluetoothDevice?>(
              stream: _bluetoothService.connectedDeviceStream,
              initialData: _bluetoothService.connectedDevice,
              builder: (context, snapshot) {
                bool isConnected = snapshot.data?.address == device.address;
                return ListTile(
                  title: Text(
                    device.name ?? 'Unnamed device',
                    style: TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
                  ),
                  subtitle: Text(
                    device.address,
                    style: TextStyle(color: isDarkTheme ? Colors.white70 : Colors.black54),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      if (isConnected) {
                        await _disconnectFromDevice();
                      } else {
                        await _connectToDevice(device);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isConnected ? 'Disconnect' : 'Connect',
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
