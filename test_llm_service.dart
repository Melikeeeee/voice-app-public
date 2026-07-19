import 'lib/llm_service.dart';

void main() async {
  print('Testing LlmService with weather query...');
  final llm = LlmService();
  final result = await llm.processSpeech('İstanbulda hava kaç derece');
  print('Result: ' + result.toString());
}
