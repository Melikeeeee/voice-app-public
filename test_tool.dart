import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() async {
  const String apiKey = 'YOUR_API_KEY_HEREIRrlju8h7P15UP0OpKf4R5o-A';
  
  final model = GenerativeModel(
    model: 'gemini-flash-latest',
    apiKey: apiKey,
    tools: [
      Tool(functionDeclarations: [
        FunctionDeclaration(
          'getWeather',
          'Belirli bir şehrin güncel hava durumunu getirir.',
          Schema(SchemaType.object, properties: {
            'city': Schema(SchemaType.string, description: 'Şehrin adı, örn. İstanbul')
          }, requiredProperties: ['city'])
        )
      ])
    ],
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
    )
  );

  try {
    print('Testing gemini-flash-latest with tools...');
    final response = await model.generateContent([Content.text("İstanbulda hava kaç derece?")]);
    if (response.functionCalls.isNotEmpty) {
      print('Function call detected: ' + response.functionCalls.first.name);
    } else {
      print('Response: ' + (response.text ?? 'null'));
    }
  } catch (e) {
    print('Error caught: ' + e.toString());
  }
  exit(0);
}
