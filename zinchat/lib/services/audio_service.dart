import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class AudioService {
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _currentRecordingPath;
  final int _recordingDuration = 0; // Track duration in seconds
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final _capturedAmplitudes = <double>[];
  final _amplitudeController = StreamController<double>.broadcast();

  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Stream<Duration> get positionStream => _audioPlayer.onPositionChanged;
  Stream<Duration> get durationStream => _audioPlayer.onDurationChanged;
  Stream<void> get onComplete => _audioPlayer.onPlayerComplete;

  bool get isRecording => _isRecording;
  int get recordingDuration => _recordingDuration;

  // Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Start recording
  Future<bool> startRecording() async {
    try {
      // Check permission
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        print('Microphone permission denied');
        return false;
      }

      // Create temporary file path
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/voice_$timestamp.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _capturedAmplitudes.clear();
      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .listen((amp) {
        final normalized = (((amp.current) + 60) / 60).clamp(0.0, 1.0);
        _capturedAmplitudes.add(normalized);
        if (_capturedAmplitudes.length > 180) {
          _capturedAmplitudes.removeAt(0);
        }
        if (!_amplitudeController.isClosed) {
          _amplitudeController.add(normalized);
        }
      });
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  // Stop recording and return file
  Future<File?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      await _amplitudeSubscription?.cancel();

      if (path != null) {
        return File(path);
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      _isRecording = false;
      await _amplitudeSubscription?.cancel();

      // Delete the file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error canceling recording: $e');
    }
  }

  // Get recording duration (in seconds)
  Future<int> getRecordingDuration(File file) async {
    try {
      // For simplicity, we'll estimate from file size
      // More accurate would require audio processing
      final bytes = await file.length();
      final durationSeconds = (bytes / 16000).round(); // Rough estimate
      return durationSeconds;
    } catch (e) {
      return 0;
    }
  }

  // Play audio file (with caching for remote URLs)
  Future<void> playAudio(String filePath) async {
    try {
      if (filePath.startsWith('http')) {
        // Check if already cached
        final cachedFile = await _getCachedAudioFile(filePath);
        if (cachedFile != null && await cachedFile.exists()) {
          print('Playing cached audio: ${cachedFile.path}');
          await _audioPlayer.play(DeviceFileSource(cachedFile.path));
        } else {
          // Download and cache, then play from cache
          print('Downloading and caching audio...');
          final downloadedFile = await _downloadAndCacheAudio(filePath);
          if (downloadedFile != null) {
            await _audioPlayer.play(DeviceFileSource(downloadedFile.path));
          } else {
            // Fallback to streaming if download fails
            await _audioPlayer.play(UrlSource(filePath));
          }
        }
      } else {
        await _audioPlayer.play(DeviceFileSource(filePath));
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  // Get cached audio file path
  Future<File?> _getCachedAudioFile(String url) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final fileName = url.hashCode.abs().toString() + '.m4a';
      final cachedFile = File('${cacheDir.path}/audio_cache/$fileName');
      return cachedFile;
    } catch (e) {
      print('Error getting cached file: $e');
      return null;
    }
  }

  // Download and cache audio file
  Future<File?> _downloadAndCacheAudio(String url) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final audioCacheDir = Directory('${cacheDir.path}/audio_cache');
      
      // Create cache directory if it doesn't exist
      if (!await audioCacheDir.exists()) {
        await audioCacheDir.create(recursive: true);
      }

      final fileName = url.hashCode.abs().toString() + '.m4a';
      final cachedFile = File('${audioCacheDir.path}/$fileName');

      // Download file using http package
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print('Failed to download audio: ${response.statusCode}');
        return null;
      }
      
      // Save to cache
      await cachedFile.writeAsBytes(response.bodyBytes);
      print('Audio cached successfully: ${cachedFile.path}');
      return cachedFile;
    } catch (e) {
      print('Error downloading and caching audio: $e');
      return null;
    }
  }

  // Stop audio playback
  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  // Get player state
  PlayerState get playerState => _audioPlayer.state;

  // Dispose
  Future<void> dispose() async {
    await _amplitudeSubscription?.cancel();
    await _amplitudeController.close();
    await _recorder.dispose();
    await _audioPlayer.dispose();
  }

  // Convert captured amplitudes into fixed sample list for waveform rendering
  List<double> getWaveformSamples({int sampleCount = 32}) {
    if (_capturedAmplitudes.isEmpty) {
      return List<double>.filled(sampleCount, 0.2);
    }

    final samples = <double>[];
    final step = _capturedAmplitudes.length / sampleCount;
    for (var i = 0; i < sampleCount; i++) {
      final start = (i * step).floor();
      final end = (((i + 1) * step).ceil()).clamp(start + 1, _capturedAmplitudes.length);
      final slice = _capturedAmplitudes.sublist(start, end);
      final avg = slice.reduce((a, b) => a + b) / slice.length;
      samples.add(avg.clamp(0.05, 1.0));
    }
    return samples;
  }

  void resetWaveformSamples() {
    _capturedAmplitudes.clear();
  }
}