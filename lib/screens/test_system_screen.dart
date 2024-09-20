import 'dart:convert'; // For utf8.encode
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_service.dart'; // Import your Bluetooth service

void logMessage(String message) {
  print(message);
}

class TestSystemScreen extends StatefulWidget {
  const TestSystemScreen({super.key});

  @override
  _TestSystemScreenState createState() => _TestSystemScreenState();
}

class _TestSystemScreenState extends State<TestSystemScreen> with WidgetsBindingObserver {
  final BluetoothService _bluetoothService = BluetoothService();
  BluetoothConnection? _connection;
  bool _pinEntered = false;
  final TextEditingController _pinController = TextEditingController();
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? _currentlyConnectingDevice; // Track device being connected
  List<BluetoothDevice> _pairedDevices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeBluetooth();
    _getPairedDevices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    _disconnectBluetooth();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _getPairedDevices();
    }
  }

  Future<void> _initializeBluetooth() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();

    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.location.isGranted) {
      await _bluetoothService.initialize();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Permissions not granted'),
      ));
    }
  }

  Future<void> _getPairedDevices() async {
    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() {
      _pairedDevices = devices;
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _currentlyConnectingDevice = device;
    });

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        _connectedDevice = device;
        _currentlyConnectingDevice = null;
      });
      logMessage('Connected to the device');
    } catch (e) {
      setState(() {
        _currentlyConnectingDevice = null;
      });
      logMessage('Could not connect to device: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to device.')),
      );
    }
  }

  void _disconnectBluetooth() {
    if (_connection != null) {
      _connection!.dispose();
      _connection = null;
      setState(() {
        _connectedDevice = null;
      });
      logMessage('Disconnected from the device');
    }
  }

  void _checkPinAndProceed() {
    if (_pinController.text == "1234") {
      setState(() {
        _pinEntered = true;
      });
      if (_bluetoothService.connectedDevice != null && _connection == null) {
        _connectToDevice(_bluetoothService.connectedDevice!);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incorrect PIN. Please try again.')),
      );
    }
  }

  void _sendCommand(String command) {
    if (_connection != null) {
      _connection!.output.add(utf8.encode(command + "\r\n")); // Send command with newline
      logMessage('Command sent: $command');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No device connected.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Test System Screen',
          style: TextStyle(fontSize: 20), // Adjust the text size if needed
        ),
        backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.orangeAccent,
        titleTextStyle: TextStyle(
          color: isDarkTheme ? Colors.orange : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: _pinEntered
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _connectedDevice != null
                    ? 'Connected to ${_connectedDevice!.name}'
                    : 'Bluetooth is disconnected.',
                style: TextStyle(
                  fontSize: 20,
                  color: _connectedDevice != null ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _pairedDevices.length,
                  itemBuilder: (context, index) {
                    final device = _pairedDevices[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          device.name ?? 'Unknown Device',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkTheme ? Colors.white : Colors.black), // Adjust text color based on theme
                        ),
                        trailing: _connectedDevice == device
                            ? ElevatedButton.icon(
                          onPressed: _disconnectBluetooth,
                          icon: Icon(Icons.bluetooth_disabled, color: Colors.white),
                          label: Text('Disconnect', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                        )
                            : ElevatedButton.icon(
                          onPressed: () => _connectToDevice(device),
                          icon: _currentlyConnectingDevice == device
                              ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                              : Icon(Icons.bluetooth, color: Colors.white),
                          label: Text(
                            _currentlyConnectingDevice == device
                                ? 'Connecting...'
                                : 'Connect',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              // Command buttons
              Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _sendCommand('8'),
                          child: Text(
                            'Alarm & LED Test',
                            textAlign: TextAlign.center, // Center the text
                            style: TextStyle(
                              color: Colors.white, // Set text color to white
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            elevation: 5, // Adjust the elevation value as needed
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _sendCommand('9'),
                          child: Text(
                            'Waterpump & Fan Test',
                            textAlign: TextAlign.center, // Centers the text
                            style: TextStyle(
                              color: Colors.white, // Sets the text color to white
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            elevation: 5, // Adjust the elevation value as needed
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _sendCommand('5'),
                          child: Text(
                            'Full system test',
                            textAlign: TextAlign.center, // Centers the text
                            style: TextStyle(
                              color: Colors.white, // Sets the text color to white
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            elevation: 5, // Adjust the elevation value as needed
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // New paragraph added here
              Text(
                'After entering the PIN, the Connect Bluetooth for Calling will be disconnected as soon as it is submitted',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkTheme ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'Enter "1234" PIN to access',
                style: TextStyle(
                  fontSize: 20,
                  color: isDarkTheme ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'PIN',
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPinAndProceed,
                child: Text(
                  'Submit',
                  style: TextStyle(color: Colors.white), // White text color
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Blue background color
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
