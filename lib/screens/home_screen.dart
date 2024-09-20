import 'dart:typed_data'; // Import this for Uint8List
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences for recording status
import 'app_storage.dart'; // Import app_storage to load saved contacts
import 'bluetooth_service.dart'; // Import BluetoothService

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, String?>> _contacts = [];
  List<String> _uploadedNumbers = []; // List to store uploaded numbers from Arduino
  bool _showNumbersCard = false; // Controls visibility of the card
  final BluetoothService _bluetoothService = BluetoothService();
  bool _isBluetoothConnected = false;
  bool _isRecordingAvailable = false; // New state variable for recording status

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadContacts(); // Automatically load contacts when the HomeScreen initializes
    _initializeBluetooth();
    _checkRecordingStatus(); // Check recording status when the screen initializes
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeBluetooth(); // Refresh Bluetooth status when resuming
    }
  }

  Future<void> _loadContacts() async {
    final contacts = await loadContacts(); // Load contacts from storage
    setState(() {
      _contacts = contacts; // Update the UI with loaded contacts
    });
  }

  Future<void> _initializeBluetooth() async {
    await _bluetoothService.initialize();

    // Listen for changes in Bluetooth connection status
    _bluetoothService.connectedDeviceStream.listen((device) {
      setState(() {
        _isBluetoothConnected = device != null;
      });
    });

    // Check Bluetooth status initially
    setState(() {
      _isBluetoothConnected = _bluetoothService.connectedDevice != null;
    });
  }

  Future<void> _uploadContacts() async {
    if (!_isBluetoothConnected) {
      print("Bluetooth not connected");
      return;
    }

    // Step 1: Clear existing numbers
    final clearCommand = Uint8List.fromList('C\n'.codeUnits);
    await _bluetoothService.sendData(clearCommand);

    // Wait for Arduino to process the clear command
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 2: Upload new contacts
    for (int i = 0; i < _contacts.length; i++) {
      final contact = _contacts[i];
      final number = contact['number']?.trim() ?? ''; // Ensure no extra spaces
      if (number.isNotEmpty) {
        // Send each number with newline termination
        final data = Uint8List.fromList("N$number\n".codeUnits);
        await _bluetoothService.sendData(data);

        // Delay to ensure Arduino can process each number
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  Future<void> _listUploadedNumbers() async {
    if (!_isBluetoothConnected) {
      print("Bluetooth not connected");
      return;
    }

    // Send the command to list numbers
    final listCommand = Uint8List.fromList('L\n'.codeUnits);
    await _bluetoothService.sendData(listCommand);

    // Clear the previous numbers
    _uploadedNumbers.clear();

    // Read the numbers from the Bluetooth device
    while (true) {
      final receivedData = await _bluetoothService.readData();
      if (receivedData == null || receivedData.trim().isEmpty) break; // Exit loop if no more data

      // Add each received number to the list
      _uploadedNumbers.add(receivedData.trim());
    }

    setState(() {
      _showNumbersCard = _uploadedNumbers.isNotEmpty; // Show card if any numbers are received
    });
  }

  Future<void> _deleteNumbers() async {
    if (!_isBluetoothConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth not connected')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Do you want to delete the numbers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      // Send delete command
      final deleteCommand = Uint8List.fromList('C\n'.codeUnits);
      await _bluetoothService.sendData(deleteCommand);

      // Update recording status after deletion
      await _checkRecordingStatus(); // Refresh the recording status
    }
  }

  void _removeNumbersCard() {
    setState(() {
      _showNumbersCard = false; // Hide the card from the frontend UI
    });
  }

  Future<void> _checkRecordingStatus() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('wavpath'); // Get the recording path
    setState(() {
      _isRecordingAvailable = path != null && path.isNotEmpty; // Check if recording exists
    });
  }

  @override
  Widget build(BuildContext context) {
    final contactCount = _contacts.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              // New Card for Recording Status at the top
// New Card for Recording Status at the top
              Container(
                width: double.infinity, // Expand to fill the width
                height: 100,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Text(
                            _isRecordingAvailable ? 'Save Recording' : 'No Recording Available',
                            style: TextStyle(
                              fontSize: 18,
                              color: _isRecordingAvailable ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!_isRecordingAvailable) // Show this text only if no recording is available
                          Text(
                            'Not OTG Connect',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity, // Expand to fill the width
                height: 250,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Contacts: $contactCount',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        // Conditionally show the 'Upload Contacts' button if contactCount is greater than 0
                        if (contactCount > 0)
                          ElevatedButton(
                            onPressed: _uploadContacts, // Updated onPressed
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue, // Background color
                              foregroundColor: Colors.white, // Text color
                            ),
                            child: const Text('Upload Contacts'),
                          ),
                        const SizedBox(height: 10),
                        // Show Uploaded Button
                        ElevatedButton(
                          onPressed: _listUploadedNumbers, // OnPressed to send "L" command
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, // Background color
                            foregroundColor: Colors.white, // Text color
                          ),
                          child: const Text('Show Uploaded'),
                        ),
                        const SizedBox(height: 10),
                        // New Button to delete numbers
                        ElevatedButton(
                          onPressed: _deleteNumbers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red, // Background color
                            foregroundColor: Colors.white, // Text color
                          ),
                          child: const Text('Delete Numbers'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity, // Expand to fill the width
                height: 100,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bluetooth Status',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isBluetoothConnected ? 'Bluetooth Connected' : 'Bluetooth Not Connected',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isBluetoothConnected ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Uploaded Numbers Section (1 card for all numbers)
              if (_showNumbersCard && _uploadedNumbers.isNotEmpty)
                Container(
                  width: double.infinity, // Expand to fill the width
                  constraints: BoxConstraints(maxHeight: 300), // Set a maximum height for the card
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Uploaded Numbers:',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: _removeNumbersCard, // Hide the card on tap
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Wrap the Column with SingleChildScrollView
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _uploadedNumbers.join(', '), // Join numbers with comma separation
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.visible, // Ensures the text does not get clipped
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
