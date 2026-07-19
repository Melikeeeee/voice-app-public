import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() async {
  const String apiKey = 'YOUR_API_KEY_HEREIRrlju8h7P15UP0OpKf4R5o-A';
  
  final modelsToTest = [
    'gemini-2.0-flash',
    'gemini-2.5-pro',
    'gemini-3-pro-preview',
    'gemini-flash-latest'
  ];

  for (final modelName in modelsToTest) {
    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
    );

    try {
      print('\\nTesting model: ' + modelName + '...');
      final response = await model.generateContent([Content.text("Merhaba")]);
      print('Success! Response: ' + (response.text ?? 'null'));
    } catch (e) {
      print('Failed: ' + e.toString());
    }
  }
  exit(0);
}
