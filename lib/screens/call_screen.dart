import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'; // Import Bluetooth package
import 'app_storage.dart'; // Import your app_storage.dart

class CallScreen extends StatefulWidget {
  const CallScreen({Key? key}) : super(key: key);

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  List<Map<String, String>> _contacts = [];
  List<Contact> _phoneContacts = [];
  List<Contact> _filteredContacts = [];
  String _searchQuery = '';
  static const int _maxContacts = 4; // Define the maximum number of contacts
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN; // Bluetooth state

  @override
  void initState() {
    super.initState();
    _loadContacts(); // Load contacts when the screen initializes
    _requestPermissions();
  }

  Future<void> _showConfirmationDialog(String title, String content, VoidCallback onConfirm) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDuplicateMessage() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Duplicate Contact'),
          content: const Text('This number is already added.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLimitReachedMessage() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limit Reached'),
          content: const Text('You have reached the maximum number of contacts allowed.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBluetoothNotConnectedMessage() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bluetooth Not Connected'),
          content: const Text('HC05 is not connected. Please connect to HC05 before uploading.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveContact() async {
    final name = _nameController.text;
    final number = _numberController.text;

    if (name.isNotEmpty && number.isNotEmpty) {
      final contacts = await loadContacts(); // Updated
      final isDuplicate = contacts.any((contact) => contact['number'] == number);

      if (isDuplicate) {
        _showDuplicateMessage();
        return;
      }

      contacts.add({'name': name, 'number': number});
      await saveContacts(contacts); // Updated
      _loadContacts();
      _nameController.clear();
      _numberController.clear();
    }
  }

  Future<void> _loadContacts() async {
    final contacts = await loadContacts(); // Updated
    setState(() {
      _contacts = contacts;
    });
  }

  Future<void> _deleteContact(int index) async {
    final contact = _contacts[index];
    _showConfirmationDialog(
      'Delete Contact',
      'Are you sure you want to delete ${contact['name']}?',
          () async {
        final contacts = await loadContacts(); // Updated
        contacts.removeAt(index);
        await saveContacts(contacts); // Updated
        _loadContacts();
      },
    );
  }

  Future<void> _requestPermissions() async {
    if (await Permission.contacts.request().isGranted) {
      _loadPhoneContacts();
    }
  }

  Future<void> _loadPhoneContacts() async {
    final contacts = await ContactsService.getContacts();
    setState(() {
      _phoneContacts = contacts.toList();
      _filteredContacts = _phoneContacts;
    });
  }

  void _showAddContactOptions() {
    if (_contacts.length >= _maxContacts) {
      _showLimitReachedMessage();
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.keyboard, color: Colors.blue),
              title: Text('Enter Manual Number'),
              onTap: () {
                Navigator.pop(context);
                _showManualEntryDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.contacts, color: Colors.blue),
              title: Text('Select from Phonebook'),
              onTap: () {
                Navigator.pop(context);
                _showPhonebook();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditContactOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.edit, color: Colors.orange),
              title: Text('Edit Number'),
              onTap: () {
                Navigator.pop(context);
                _showEditManualEntryDialog(index);
              },
            ),
            ListTile(
              leading: Icon(Icons.contacts, color: Colors.orange),
              title: Text('Select from Phonebook'),
              onTap: () {
                Navigator.pop(context);
                _showPhonebookForEdit(index);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteContact(index);
              },
            ),
          ],
        );
      },
    );
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Manual Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Enter Name'),
              ),
              TextField(
                controller: _numberController,
                decoration: const InputDecoration(labelText: 'Enter Number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveContact();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditManualEntryDialog(int index) {
    final contact = _contacts[index];
    _nameController.text = contact['name']!;
    _numberController.text = contact['number']!;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Enter Name'),
              ),
              TextField(
                controller: _numberController,
                decoration: const InputDecoration(labelText: 'Enter Number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _editContact(index);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editContact(int index) async {
    final name = _nameController.text;
    final number = _numberController.text;

    if (name.isNotEmpty && number.isNotEmpty) {
      final contacts = await loadContacts(); // Updated
      contacts[index] = {'name': name, 'number': number};
      await saveContacts(contacts); // Updated
      _loadContacts();
      _nameController.clear();
      _numberController.clear();
    }
  }

  void _showPhonebook() async {
    try {
      final contact = await ContactsService.openDeviceContactPicker();
      if (contact != null) {
        setState(() {
          _nameController.text = contact.displayName ?? '';
          _numberController.text = contact.phones!.isNotEmpty ? contact.phones!.first.value ?? '' : '';
        });
        _saveContact();
      }
    } catch (e) {
      // Handle the error, e.g., permission denied
    }
  }

  void _showPhonebookForEdit(int index) async {
    try {
      final contact = await ContactsService.openDeviceContactPicker();
      if (contact != null) {
        setState(() {
          _nameController.text = contact.displayName ?? '';
          _numberController.text = contact.phones!.isNotEmpty ? contact.phones!.first.value ?? '' : '';
        });
        _editContact(index);
      }
    } catch (e) {
      // Handle the error, e.g., permission denied
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Screen'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  elevation: 4,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(contact['name']!),
                    subtitle: Text(contact['number']!),
                    trailing: IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditContactOptions(index),
                    ),
                  ),
                );
              },
            ),
          ),

        ],
      ),
      floatingActionButton: _contacts.length >= _maxContacts
          ? null
          : FloatingActionButton(
        onPressed: _showAddContactOptions,
        child: const Icon(Icons.add),
      ),
    );
  }
}

