import 'lib/llm_service.dart';

void main() async {
  print('Testing Groq LlmService with weather query...');
  final llm = LlmService();
  try {
    final result = await llm.processSpeech('anneme ne yapıyorsun yaz');
    print('Result: ' + result.toString());
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
