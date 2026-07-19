import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() async {
  const String apiKey = 'YOUR_API_KEY_HEREIRrlju8h7P15UP0OpKf4R5o-A';
  
  final model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: apiKey,
  );

  try {
    print('Testing gemini-1.5-flash...');
    final response = await model.generateContent([Content.text("Merhaba")]);
    print('Success! Response: ' + (response.text ?? 'null'));
  } catch (e) {
    print('Failed: ' + e.toString());
  }
  exit(0);
}
