import 'dart:convert';
import 'dart:io';

void main() async {
  const String apiKey = 'YOUR_API_KEY_HEREIRrlju8h7P15UP0OpKf4R5o-A';
  var url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=' + apiKey);
  
  try {
    final request = await HttpClient().getUrl(url);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    final models = json['models'] as List;
    for (var m in models) {
      print(m['name'] + ' - ' + (m['supportedGenerationMethods']?.toString() ?? '[]'));
    }
  } catch (e) {
    print('Error caught: ' + e.toString());
  }
  exit(0);
}
