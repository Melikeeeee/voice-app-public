import 'dart:convert';
import 'package:http/http.dart' as http;
import 'weather_service.dart';
import 'constants.dart';

class LlmService {
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  final List<Map<String, dynamic>> _mesajGecmisi = [];

  LlmService() {
    _mesajGecmisi.add({"role": "system", "content": Constants.systemPrompt});
  }

  Future<Map<String, dynamic>?> processSpeech(String text) async {
    try {
      final now = DateTime.now();
      final timeContext = "Şu anki tarih ve saat: ${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}.";
      
      _mesajGecmisi.add({"role": "user", "content": "$timeContext\nKullanıcının söylediği: $text"});

      // Sadece son 10 mesajı tut, en baştaki sistem komutunu asla silme. 
      // 1 system + 10 history = 11. Limit aşılırsa aradaki eski mesajları çıkar.
      if (_mesajGecmisi.length > 11) {
        int silinecekSayi = _mesajGecmisi.length - 11;
        _mesajGecmisi.removeRange(1, 1 + silinecekSayi);
      }

      final tools = [
        {
          "type": "function",
          "function": {
            "name": "getWeather",
            "description": "Kullanıcının hava durumunu öğrenmek istediği şehrin bilgisini getirir. Şehir belirtilmemişse varsayılan olarak Bursa'yı kullanır.",
            "parameters": {
              "type": "object",
              "properties": {
                "city": {
                  "type": "string",
                  "description": "Hava durumu sorulan şehrin adı. Eğer kullanıcı şehir belirtmediyse 'Bursa' yaz."
                }
              },
              "required": ["city"]
            }
          }
        }
      ];

      var responseData = await _makeGroqRequest(_mesajGecmisi, tools: tools);

      // Fonksiyon çağrısı (Function Calling) var mı kontrol et
      if (responseData['choices'][0]['message']['tool_calls'] != null) {
        final toolCall = responseData['choices'][0]['message']['tool_calls'][0];
        if (toolCall['function']['name'] == 'getWeather') {
          final args = jsonDecode(toolCall['function']['arguments']);
          final city = args['city'];
          final weatherInfo = await WeatherService.getWeather(city);

          // Asistanın tool call mesajını ekle
          _mesajGecmisi.add(responseData['choices'][0]['message']);
          
          // Tool'un cevabını ekle
          _mesajGecmisi.add({
            "role": "tool",
            "tool_call_id": toolCall['id'],
            "name": "getWeather",
            "content": weatherInfo
          });

          // Tekrar istek at (cevabı oluşturması için)
          responseData = await _makeGroqRequest(_mesajGecmisi);
        }
      }

      var responseText = responseData['choices'][0]['message']['content'];
      if (responseText != null) {
        try {
          // Modelden gelen yanıt içindeki { } bloğunu Regex ile bul (Sohbet kısımlarını atla)
          final regex = RegExp(r'\{[\s\S]*\}');
          final match = regex.firstMatch(responseText);
          
          if (match != null) {
            final jsonStr = match.group(0)!;
            _mesajGecmisi.add({"role": "assistant", "content": jsonStr});
            return jsonDecode(jsonStr) as Map<String, dynamic>;
          } else {
            print('LLM Error: JSON nesnesi bulunamadı. Yanıt: $responseText');
            return _offlineBrain(text);
          }
        } catch (e) {
          print('LLM JSON Parse Error: $e');
          return _offlineBrain(text);
        }
      }
      throw Exception('Empty response from model');

    } catch (e) {
      print('LLM Error: $e');
      return _offlineBrain(text);
    }
  }

  Future<Map<String, dynamic>> _makeGroqRequest(List<Map<String, dynamic>> messages, {List<Map<String, dynamic>>? tools}) async {
    final body = {
      "model": "llama-3.3-70b-versatile",
      "messages": messages,
      "temperature": 0.3,
      "response_format": {"type": "json_object"}
    };
    
    if (tools != null) {
      body["tools"] = tools;
      body["tool_choice"] = "auto";
      // Function Calling kullanırken json_object formatı bazı Llama modellerinde hata verebilir, 
      // bu yüzden tool gönderiliyorsa formatı kaldırıyoruz.
      body.remove("response_format"); 
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        "Authorization": "Bearer ${Constants.groqApiKey}",
        "Content-Type": "application/json"
      },
      body: jsonEncode(body)
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception("Groq API Error: ${response.body}");
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Map<String, dynamic> _offlineBrain(String text) {
    String t = text.toLowerCase().replaceAll("'", " ").replaceAll("’", " ");
    
    if (t.contains("acil") || t.contains("yardım") || t.contains("düştüm") || t.contains("kötü") || t.contains("kork")) {
      return {"type": "acil_durum"};
    }
    if (t.contains("ara")) {
        List<String> words = t.split(" ");
        int idx = words.indexWhere((w) => w.contains("ara"));
        String kisi = (idx > 0) ? words[idx-1] : words.first;
        kisi = kisi.replaceAll("yi", "").replaceAll("yı", "").replaceAll("ye", "").replaceAll("ya", "");
        return {"type": "arama", "kisi": kisi};
    }
    if (t.contains("mesaj")) {
        List<String> words = t.split(" ");
        int idx = words.indexWhere((w) => w.contains("mesaj"));
        String kisi = (idx > 0) ? words[idx-1] : words.first;
        kisi = kisi.replaceAll("ye", "").replaceAll("ya", "").replaceAll("e", "").replaceAll("a", "");
        return {"type": "whatsapp", "kisi": kisi, "mesaj": "Nasılsın, sana mesaj göndermek istedim."};
    }
    if (t.contains("merhaba") || t.contains("selam") || t.contains("günaydın") || t.contains("iyi akşamlar") || t.contains("nasılsın")) {
        return {"type": "sohbet", "mesaj": "Merhaba canım anneannem, ben harikayım. Sen nasılsın, sana nasıl yardımcı olabilirim?"};
    }
    if (t.contains("saat")) {
        final now = DateTime.now();
        return {"type": "sohbet", "mesaj": "Saat şu an ${now.hour} u ${now.minute} geçiyor canım anneannem."};
    }
    if (t.contains("günlerden") || t.contains("bugün") || t.contains("hangi gün")) {
        final now = DateTime.now();
        final gunler = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"];
        final gun = gunler[now.weekday - 1];
        return {"type": "sohbet", "mesaj": "Bugün günlerden $gun canım anneannem."};
    }
    return {"type": "sohbet", "mesaj": "Tamam canım anneannem, seni anlıyorum."};
  }
}
