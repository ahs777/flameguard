import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:convert'; // For JSON encoding/decoding
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // For getApplicationDocumentsDirectory
import 'dart:io'; // For File operations
import 'app_storage.dart'; // Your app storage functions
import 'bluetooth_service.dart'; // Your Bluetooth service

class RecordingListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recordings;
  final Function(String) onDelete;

  const RecordingListScreen(
      {super.key, required this.recordings, required this.onDelete});

  @override
  _RecordingListScreenState createState() => _RecordingListScreenState();
}

class _RecordingListScreenState extends State<RecordingListScreen> {
  final Map<int, AudioPlayer> _players = {};
  final Map<int, bool> _isPlaying = {};
  final Map<int, Duration> _currentPosition = {};
  final Map<int, Duration> _durations = {};
  Map<int, bool> _isSet = {};
  int? _currentlyPlayingIndex;
  int? _currentlySetIndex;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  final BluetoothService _bluetoothService =
      BluetoothService(); // Initialize BluetoothService

  @override
  void initState() {
    super.initState();
    _initializePlayers();
    _loadSetStates();
  }

  void _initializePlayers() {
    for (int i = 0; i < widget.recordings.length; i++) {
      _players[i] = AudioPlayer();
      _isPlaying[i] = false;
      _currentPosition[i] = Duration.zero;
      _durations[i] = Duration.zero;
      _isSet[i] = false;

      final duration = widget.recordings[i]['duration'];
      if (duration != null) {
        _durations[i] = Duration(milliseconds: duration);
      }

      _players[i]!.onPlayerStateChanged.listen((PlayerState state) {
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          setState(() {
            _isPlaying[i] = false;
            if (_currentlyPlayingIndex == i) {
              _currentlyPlayingIndex = null;
            }
          });
          _positionSubscription?.cancel();
        }
      });

      _players[i]!.onPositionChanged.listen((position) {
        setState(() {
          _currentPosition[i] = position;
        });
      });

      _players[i]!.onDurationChanged.listen((duration) {
        setState(() {
          _durations[i] = duration;
        });
      });
    }
  }

  Future<void> _loadSetStates() async {
    final jsonData =
        await getRecordings(); // Load recordings list from app_storage
    if (jsonData != null) {
      final List<dynamic> data = jsonDecode(jsonData);
      setState(() {
        _isSet = {};
        _currentlySetIndex = null;
        for (int i = 0; i < data.length; i++) {
          final recording = data[i];
          final isSet = recording['isSet'] ?? false;
          _isSet[i] = isSet;
          if (isSet) {
            _currentlySetIndex = i;
          }
        }
      });
    }
  }

  Future<void> _saveSetState(int index, bool isSet) async {
    final jsonData =
        await getRecordings(); // Load recordings list from app_storage
    if (jsonData != null) {
      final List<dynamic> data = jsonDecode(jsonData);
      data[index]['isSet'] = isSet;
      await saveRecordings(
          jsonEncode(data)); // Save updated list to app_storage
    }
  }

  @override
  void dispose() {
    for (var player in _players.values) {
      player.dispose();
    }
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }

  void _togglePlayPause(int index) async {
    final player = _players[index]!;
    final isPlaying = _isPlaying[index] ?? false;

    if (isPlaying) {
      await player.pause();
      setState(() {
        _isPlaying[index] = false;
      });
    } else {
      if (_currentlyPlayingIndex != null && _currentlyPlayingIndex != index) {
        await _players[_currentlyPlayingIndex!]!.stop();
        setState(() {
          _isPlaying[_currentlyPlayingIndex!] = false;
          _currentPosition[_currentlyPlayingIndex!] = Duration.zero;
        });
      }

      await player.play(DeviceFileSource(widget.recordings[index]['path']));
      setState(() {
        _isPlaying[index] = true;
        _currentlyPlayingIndex = index;
      });

      _positionSubscription = player.onPositionChanged.listen((position) {
        setState(() {
          _currentPosition[index] = position;
        });
      });

      _players[index]!.onDurationChanged.listen((duration) {
        setState(() {
          _durations[index] = duration;
        });
      });
    }
  }

  void _deleteRecording(int index) async {
    final path = widget.recordings[index]['path'];
    final bool shouldDelete = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Recording'),
            content: const Text(
                'Are you sure you want to delete this recording? This action cannot be undone.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldDelete) {
      widget.onDelete(path);
      setState(() {
        widget.recordings.removeAt(index);
        _saveRecordings(); // Save updated recordings list
      });
    }
  }

  Future<void> _toggleSetRecording(int index) async {
  final isSet = !_isSet[index]!;

  final shouldSet = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Set For Voicemail'),
      content: const Text('Are you sure you want to set this recording for Voicemail? Only one recording can be set at a time.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  if (shouldSet == true) {
    try {
      // Send the recording first
      final sendResult = await _sendRecording(index);

      if (sendResult) {
        // If sending is successful, update the set state
        await _saveSetState(index, isSet);
        setState(() {
          _isSet[index] = isSet;
          _currentlySetIndex = isSet ? index : null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording has been set and sent successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send the recording.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }
}

 Future<bool> _sendRecording(int index) async {
  final path = widget.recordings[index]['path'];
  final directory = await getApplicationDocumentsDirectory();
  final tempPath = '${directory.path}/001.mp3';

  print('Original path: $path');
  print('Temporary path: $tempPath');

  try {
    final file = File(path);
    if (!await file.exists()) {
      print('File does not exist at path: $path');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File not found: $path')),
      );
      return false; // Indicate failure
    }

    await file.copy(tempPath);
    print('File copied to: $tempPath');

    final connectedDevice = _bluetoothService.connectedDevice;
    if (connectedDevice != null) {
      final tempFile = File(tempPath);
      final fileBytes = await tempFile.readAsBytes();
      await _bluetoothService.sendData(fileBytes); // Send the file data
      print('File sent successfully.');
      return true; // Indicate success
    } else {
      print('No Bluetooth device connected.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connect to a Bluetooth device.')),
      );
      return false; // Indicate failure
    }
  } catch (e) {
    print('Error occurred: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send the recording: $e')),
    );
    return false; // Indicate failure
  }
}

  void _onSliderChanged(double value, int index) {
    final player = _players[index]!;
    final newPosition = Duration(milliseconds: value.toInt());
    player.seek(newPosition);
    setState(() {
      _currentPosition[index] = newPosition;
    });
  }

  Future<void> _saveRecordings() async {
    final jsonData = widget.recordings
        .map((recording) => {
              'path': recording['path'],
              'date': recording['date'].toIso8601String(),
              'duration': recording['duration'],
              'isSet': _isSet[widget.recordings.indexOf(recording)],
            })
        .toList();
    await saveRecordings(
        jsonEncode(jsonData)); // Save recordings list to app_storage
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings List'),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView.builder(
        itemCount: widget.recordings.length,
        itemBuilder: (context, index) {
          final recording = widget.recordings[index];
          final duration = _durations[index] ?? Duration.zero;
          final position = _currentPosition[index] ?? Duration.zero;
          final isPlaying = _isPlaying[index] ?? false;
          final date = recording['date'];

          final formattedDate = date != null
              ? DateFormat('yyyy-MM-dd – kk:mm').format(date)
              : 'Unknown Date';

          return Card(
            margin: const EdgeInsets.all(8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 5,
            child: Stack(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(10.0),
                  leading: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.blue,
                    ),
                    onPressed: () => _togglePlayPause(index),
                  ),
                  title: Text('Recording ${index + 1}',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Duration: ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(color: Colors.grey[600])),
                      Text('Date: $formattedDate',
                          style: TextStyle(color: Colors.grey[600])),
                      Slider(
                        value: position.inMilliseconds.toDouble(),
                        min: 0.0,
                        max: duration.inMilliseconds.toDouble(),
                        onChanged: (value) => _onSliderChanged(value, index),
                        activeColor: Colors.blue,
                        inactiveColor: Colors.grey,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(color: Colors.grey[600])),
                          Text(
                              '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isSet[index]!
                              ? Icons.phone_in_talk
                              : Icons.phone_disabled,
                          color: _isSet[index]! ? Colors.green : Colors.grey,
                        ),
                        onPressed: () => _toggleSetRecording(index),
                        tooltip: _isSet[index]!
                            ? 'Voicemail Set'
                            : 'Voicemail Not Set',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRecording(index),
                      ),
                    ],
                  ),
                ),
                if (_currentlySetIndex == index)
                  Positioned(
                    right: 10,
                    top: 10,
                    child:
                        Icon(Icons.check_circle, color: Colors.green, size: 24),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
