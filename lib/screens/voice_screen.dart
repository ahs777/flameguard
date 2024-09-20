import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart' as fsound;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_storage.dart'; // Make sure this imports your app's custom storage methods

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  _VoiceScreenState createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> with WidgetsBindingObserver {
  fsound.FlutterSoundRecorder _recorder = fsound.FlutterSoundRecorder();
  bool _isRecording = false;
  String _recordingPath = '';
  Timer? _timer;
  Duration _duration = Duration.zero;
  Map<String, dynamic>? _currentRecording;
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  bool _recordingButtonVisible = true; // Track visibility of the recording button

  static const int _maxRecordingDuration = 20; // Max recording time in seconds

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _recorder.openRecorder();
      await _requestPermissions();
      _loadRecording();
    } catch (e) {
      print('Initialization error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final microphoneStatus = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();
    if (!microphoneStatus.isGranted || !storageStatus.isGranted) {
      print('Permissions are not granted');
    }
  }

  Future<void> _startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingPath = '${directory.path}/001.wav'; // Save recording with name '001.wav'
      print('Starting recording at: $recordingPath'); // Log path

      setState(() {
        _recordingPath = recordingPath;
        _isRecording = true;
        _duration = Duration.zero;
        _recordingButtonVisible = true; // Show recording button
      });

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_isRecording) {
          setState(() {
            _duration += Duration(seconds: 1);
          });
          if (_duration.inSeconds >= _maxRecordingDuration) {
            _stopRecording(); // Automatically stop after 20 seconds
          }
        } else {
          timer.cancel();
        }
      });

      await _recorder.startRecorder(toFile: recordingPath, codec: fsound.Codec.pcm16WAV);
      print('Recording started successfully');
    } catch (e) {
      print('Recording start error: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      try {
        await _recorder.stopRecorder();
        print('Recording stopped. File path: $_recordingPath'); // Log path

        setState(() {
          _isRecording = false;
          _timer?.cancel();
          _currentRecording = {
            'path': _recordingPath,
            'date': DateTime.now(),
            'duration': _duration.inMilliseconds,
          };
          _recordingButtonVisible = false; // Hide recording button after recording
        });

        await _saveRecording(); // Save the file path
      } catch (e) {
        print('Recording stop error: $e');
      }
    }
  }

  Future<void> _saveRecording() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('wavpath', _recordingPath); // Save the file path
      final jsonData = jsonEncode({
        'path': _recordingPath,
        'date': (_currentRecording!['date'] as DateTime).toIso8601String(),
        'duration': _currentRecording!['duration'],
      });
      print('Saved recording: $jsonData');
      await saveRecordings(jsonData);
    } catch (e) {
      print('Error saving recording: $e');
    }
  }

  Future<void> _loadRecording() async {
    try {
      final jsonData = await getRecordings();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('wavpath');
      if (jsonData != null && path != null) {
        final data = jsonDecode(jsonData);
        setState(() {
          _currentRecording = {
            'path': data['path'],
            'date': DateTime.parse(data['date']),
            'duration': data['duration'],
          };
          _audioDuration = Duration(milliseconds: data['duration']);
          _recordingButtonVisible = false; // Hide recording button if a recording exists
        });
      } else {
        setState(() {
          _currentRecording = null; // Ensure currentRecording is null if no data is found
          _recordingButtonVisible = true; // Show recording button if no recording exists
        });
      }
    } catch (e) {
      print('Error loading recording: $e');
    }
  }

  Future<void> _deleteRecording() async {
    if (_currentRecording != null) {
      print('Attempting to delete recording...');
      try {
        final file = File(_currentRecording!['path']);
        print('Attempting to delete file at: ${file.path}');

        if (await file.exists()) {
          await file.delete();
          print('File deleted successfully.');
        } else {
          print('File does not exist.');
        }

        setState(() {
          _currentRecording = null; // Clear the current recording
          _recordingPath = ''; // Clear the recording path
          _recordingButtonVisible = true; // Show recording button after deletion
          _duration = Duration.zero; // Reset duration after deletion
        });

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('wavpath'); // Remove the path from SharedPreferences

        // Stop playback if it's currently playing
        if (_isPlaying) {
          _togglePlayPause(); // This will stop the playback
        }
      } catch (e) {
        print('Error deleting recording: $e');
      }
    } else {
      print('No recording to delete.');
    }
  }

  Future<void> _confirmDeleteRecording() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Do you want to delete this voice recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // User clicked No
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // User clicked Yes
            child: Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      print('User confirmed deletion.');
      await _deleteRecording();
      _loadRecording(); // Reload recording state after deletion
    } else {
      print('User canceled deletion.');
    }
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      try {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } catch (e) {
        print('Error pausing audio: $e');
      }
    } else {
      try {
        final file = File(_currentRecording!['path']);
        if (await file.exists()) {
          await _audioPlayer.play(DeviceFileSource(_currentRecording!['path']));
          print('Playing file: ${_currentRecording!['path']}');
          setState(() {
            _isPlaying = true;
          });

          _audioPlayer.onPositionChanged.listen((position) {
            setState(() {
              _currentPosition = position;
            });
          });

          _audioPlayer.onDurationChanged.listen((duration) {
            setState(() {
              _audioDuration = duration;
            });
          });

          _audioPlayer.onPlayerComplete.listen((event) {
            setState(() {
              _isPlaying = false;
              _currentPosition = Duration.zero; // Reset position when audio completes
            });
          });
        } else {
          print('File does not exist: ${_currentRecording!['path']}');
        }
      } catch (e) {
        print('Error playing audio: $e');
      }
    }
  }

  void _onSliderChanged(double value) {
    final newPosition = Duration(milliseconds: value.toInt());
    _audioPlayer.seek(newPosition);
    setState(() {
      _currentPosition = newPosition;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecording(); // Ensure recording is loaded when navigating back to the screen
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.detached) && _isRecording) {
      // Save recording when the app is paused or backgrounded
      _stopRecording();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _stopRecording(); // Ensure recording is stopped before dispose
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Recorder'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hide the text if the recording button is not visible
              _recordingButtonVisible
                  ? Text(
                _isRecording
                    ? '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}'
                    : '00:00',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              )
                  : Container(),
              SizedBox(height: 20),
              // Hide the button if recording is completed
              _recordingButtonVisible
                  ? GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              )
                  : Container(),
              SizedBox(height: 20),
              // Show the recording controls after recording is done
              _currentRecording != null
                  ? Column(
                children: [
                  Text(
                    'Recording from ${DateFormat('yyyy-MM-dd – kk:mm').format(_currentRecording!['date'])}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Slider(
                    value: _currentPosition.inMilliseconds.toDouble().clamp(0.0, _audioDuration.inMilliseconds.toDouble()), // Ensure value is within the bounds
                    min: 0.0,
                    max: _audioDuration.inMilliseconds > 0 ? _audioDuration.inMilliseconds.toDouble() : 1.0, // Set max to a minimum of 1.0 to avoid division by zero
                    onChanged: _onSliderChanged,
                    activeColor: Colors.blue,
                    inactiveColor: Colors.grey,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_currentPosition.inMinutes}:${(_currentPosition.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        '${_audioDuration.inMinutes}:${(_audioDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        iconSize: 64,
                        color: Colors.blue,
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        color: Colors.red,
                        onPressed: _confirmDeleteRecording, // Call confirmation method
                      ),
                    ],
                  ),
                ],
              )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }
}
