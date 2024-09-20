import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_number/mobile_number.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetSimScreen extends StatefulWidget {
  const SetSimScreen({super.key});

  @override
  _SetSimScreenState createState() => _SetSimScreenState();
}

class _SetSimScreenState extends State<SetSimScreen> {
  String _mobileNumber = '';
  List<SimCard> _simCard = <SimCard>[];
  String? _selectedSimNumber;

  @override
  void initState() {
    super.initState();

    MobileNumber.listenPhonePermission((isPermissionGranted) {
      if (isPermissionGranted) {
        initMobileNumberState();
      } else {
        debugPrint('Phone permission not granted.');
      }
    });

    initMobileNumberState();
  }

  Future<void> initMobileNumberState() async {
    if (!await MobileNumber.hasPhonePermission) {
      await MobileNumber.requestPhonePermission;
      return;
    }

    try {
      _mobileNumber = (await MobileNumber.mobileNumber) ?? 'Unknown';
      _simCard = (await MobileNumber.getSimCards) ?? <SimCard>[];
      _selectedSimNumber = await getSelectedSim(); // Retrieve selected SIM number
    } on PlatformException catch (e) {
      debugPrint("Failed to get mobile number because of '${e.message}'");
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> saveSelectedSim(String simId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_sim', simId);
  }

  Future<String?> getSelectedSim() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_sim');
  }

  Future<void> showConfirmationDialog(SimCard sim) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Selection'),
          content: Text('Are you sure you want to select the SIM with number (${sim.countryPhonePrefix}) - ${sim.number}?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () async {
                if (sim.number != null) {
                  await saveSelectedSim(sim.number!);
                  setState(() {
                    _selectedSimNumber = sim.number;
                  });
                  Navigator.of(context).pop(); // Close the dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected SIM ${sim.number} saved')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget fillCards() {
    if (_simCard.isEmpty) {
      return Text('No SIM cards found.');
    }

    List<Widget> widgets = _simCard.map((SimCard sim) {
      bool isSelected = sim.number == _selectedSimNumber;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: GestureDetector(
          onTap: () async {
            if (sim.number != null) {
              await showConfirmationDialog(sim);
            }
          },
          child: Container(
            width: double.infinity, // Set width to full screen
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[850] // Dark grey background for dark theme
                  : Colors.white, // White background for light theme
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3) // Darker shadow for dark theme
                      : Colors.grey.withOpacity(0.3), // Lighter shadow for light theme
                  offset: Offset(5, 5),
                  blurRadius: 10.0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sim Card Number:',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color, // Dynamic text color
                          ),
                        ),
                        Text(
                          '(${sim.countryPhonePrefix}) - ${sim.number ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Theme.of(context).textTheme.bodyMedium?.color, // Dynamic text color
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Carrier Name:',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color, // Dynamic text color
                          ),
                        ),
                        Text(
                          sim.carrierName ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Theme.of(context).textTheme.bodyMedium?.color, // Dynamic text color
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Country Code:',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color, // Dynamic text color
                          ),
                        ),
                        Text(
                          sim.countryIso ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Theme.of(context).textTheme.bodyMedium?.color, // Dynamic text color
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Sim Name:',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color, // Dynamic text color
                          ),
                        ),
                        Text(
                          sim.displayName ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Theme.of(context).textTheme.bodyMedium?.color, // Dynamic text color
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Sim Slot Index:',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color, // Dynamic text color
                          ),
                        ),
                        Text(
                          sim.slotIndex.toString(),
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Theme.of(context).textTheme.bodyMedium?.color, // Dynamic text color
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.call,
                      color: Colors.green,
                      size: 24.0,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();

    return Column(children: widgets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set SIM'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, // Use appBar background color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Running on: ${_selectedSimNumber ?? 'Unknown'}',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color, // Dynamic text color
                ),
              ),
              SizedBox(height: 16.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      fillCards(),
                      SizedBox(height: 16.0),
                      Text(
                        'If all the SIMs in your mobile are not showing, then go to the settings of the app and go to the requested permissions and allow the permissions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Theme.of(context).textTheme.bodySmall?.color, // Dynamic text color
                        ),
                      ),
                    ],
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
