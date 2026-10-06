import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Start recording audio
  Future<void> startRecording() async {
    try {
      // Check permission
      if (!await _recorder.hasPermission()) {
        print("Microphone permission denied");
        return;
      }

      // Get temp directory
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording with optimized settings
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // Compressed format
          sampleRate: 16000, // 16kHz (good for voice)
          numChannels: 1, // Mono
          bitRate: 32000, // 32 kbps (compressed)
        ),
        path: path,
      );

      _currentRecordingPath = path;
      _isRecording = true;
      print(" Recording started: $path");
    } catch (e) {
      print(" Recording error: $e");
    }
  }

  /// Stop recording and return file path
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      print(" Recording stopped: $path");
      return path;
    } catch (e) {
      print(" Stop recording error: $e");
      return null;
    }
  }

  /// Play audio from bytes (received from nearby)
  Future<void> playAudioFromBytes(List<int> bytes) async {
    try {
      // Save bytes to temp file
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/received_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await file.writeAsBytes(bytes);

      // Play
      await _player.play(DeviceFileSource(file.path));
      print(" Playing audio...");

      // Delete after playing
      _player.onPlayerComplete.listen((_) {
        file.delete();
      });
    } catch (e) {
      print(" Play error: $e");
    }
  }

  /// Play audio from file path
  Future<void> playAudioFromPath(String path) async {
    try {
      await _player.play(DeviceFileSource(path));
      print("Playing: $path");
    } catch (e) {
      print(" Play error: $e");
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    await _player.stop();
  }

  /// Dispose
  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
