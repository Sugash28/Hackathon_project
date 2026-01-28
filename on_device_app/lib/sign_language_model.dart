import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math';

class SignLanguageModel {
  Interpreter? _interpreter;
  bool isLoaded = false;

  final List<String> labels = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
    "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
    "U", "V", "W", "X", "Y"
  ];

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/sign_language_model.tflite');
      isLoaded = true;
      print("Sign Language Model loaded successfully!");
    } catch (e) {
      print("Error loading Sign Language Model: $e");
    }
  }

  String? predict(List<dynamic> hand) {
    if (!isLoaded || _interpreter == null) return null;

    // MediaPipe gives 21 landmarks (x, y, z).
    // Total 21 * 3 = 63 features.
    // The user mentioned input shape [1, 784] (CSV data).
    // We flatten the landmarks and pad the rest with zeros.
    
    List<double> input = [];
    for (var point in hand) {
      input.add(point['x'] as double);
      input.add(point['y'] as double);
      input.add(point['z'] as double);
    }

    // Pad to 784
    while (input.length < 784) {
      input.add(0.0);
    }
    
    // Take only first 784 if it somehow exceeds
    if (input.length > 784) {
      input = input.sublist(0, 784);
    }

    var inputTensor = [input];
    var outputTensor = List.filled(1 * labels.length, 0.0).reshape([1, labels.length]);

    _interpreter!.run(inputTensor, outputTensor);

    List<double> scores = List<double>.from(outputTensor[0]);
    double maxScore = scores.reduce(max);
    int maxIndex = scores.indexOf(maxScore);

    // Only return if confidence is reasonably high (threshold can be adjusted)
    if (maxScore > 0.5) {
      return labels[maxIndex];
    }
    return null;
  }
}
