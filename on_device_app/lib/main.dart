import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'sign_language_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await [Permission.camera].request();
  final cameras = await availableCameras();
  runApp(MaterialApp(home: MediaPipeApp(camera: cameras.first)));
}

class MediaPipeApp extends StatefulWidget {
  final CameraDescription camera;
  const MediaPipeApp({super.key, required this.camera});

  @override
  State<MediaPipeApp> createState() => _MediaPipeAppState();
}

class _MediaPipeAppState extends State<MediaPipeApp> {
  CameraController? _controller;
  static const _channel = MethodChannel('com.example.on_device_app/mediapipe');
  bool _isProcessing = false;
  List<dynamic> _hands = [];
  
  final SignLanguageModel _signModel = SignLanguageModel();
  final FlutterTts _tts = FlutterTts();
  String _detectedSign = "";
  String _lastSpoken = "";
  DateTime _lastSpeechTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initModels();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    )..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller?.startImageStream(_processFrame);
      });
  }

  Future<void> _initModels() async {
    await _signModel.loadModel();
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
  }

  void _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final String format = image.format.group.name;
      final List<Map<String, dynamic>> planes = image.planes.map((plane) {
        return {
          'bytes': plane.bytes,
          'bytesPerRow': plane.bytesPerRow,
          'bytesPerPixel': plane.bytesPerPixel,
        };
      }).toList();

      final result = await _channel.invokeMethod('detect', {
        'planes': planes,
        'width': image.width,
        'height': image.height,
        'format': format,
      });

      if (mounted) {
        setState(() {
          _hands = result;
          if (_hands.isNotEmpty) {
            final prediction = _signModel.predict(_hands[0]);
            if (prediction != null && prediction != _detectedSign) {
              _detectedSign = prediction;
              _speak(prediction);
            }
          } else {
            _detectedSign = "";
          }
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _speak(String text) async {
    final now = DateTime.now();
    if (text != _lastSpoken || now.difference(_lastSpeechTime).inSeconds > 2) {
      await _tts.speak(text);
      _lastSpoken = text;
      _lastSpeechTime = now;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('MediaPipe Hand Tracking')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: Stack(
                children: [
                  CameraPreview(_controller!),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: LandmarkPainter(_hands),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_detectedSign.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Predicted Sign: $_detectedSign',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black54,
                  child: Text(
                    'Hands Detected: ${_hands.length}',
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LandmarkPainter extends CustomPainter {
  final List<dynamic> hands;
  LandmarkPainter(this.hands);

  static const List<List<int>> connections = [
    [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8], // Index
    [5, 9], [9, 10], [10, 11], [11, 12], // Middle
    [9, 13], [13, 14], [14, 15], [15, 16], // Ring
    [13, 17], [17, 18], [18, 19], [19, 20], [0, 17] // Pinky and palm base
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    for (var hand in hands) {
      // Draw Connections
      for (var connection in connections) {
        final p1 = hand[connection[0]];
        final p2 = hand[connection[1]];
        canvas.drawLine(
          Offset(p1['x'] * size.width, p1['y'] * size.height),
          Offset(p2['x'] * size.width, p2['y'] * size.height),
          linePaint,
        );
      }

      // Draw Landmarks
      for (var point in hand) {
        canvas.drawCircle(
          Offset(point['x'] * size.width, point['y'] * size.height),
          3,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) => true;
}
