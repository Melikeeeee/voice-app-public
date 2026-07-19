import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static Future<String> getWeather(String city) async {
    try {
      // 1. Şehrin enlem ve boylamını bul
      final geoUrl = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&language=tr&format=json');
      final geoResponse = await http.get(geoUrl).timeout(const Duration(seconds: 10));
      
      if (geoResponse.statusCode != 200) {
        return "Hava durumu servisine bağlanılamadı.";
      }

      final geoData = jsonDecode(geoResponse.body);
      if (geoData['results'] == null || geoData['results'].isEmpty) {
        return "$city şehri bulunamadı.";
      }

      final double lat = (geoData['results'][0]['latitude'] as num).toDouble();
      final double lon = (geoData['results'][0]['longitude'] as num).toDouble();
      final String cityName = geoData['results'][0]['name'];

      // 2. Hava durumunu çek
      final weatherUrl = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m');
      final weatherResponse = await http.get(weatherUrl).timeout(const Duration(seconds: 10));

      if (weatherResponse.statusCode != 200) {
        return "Hava durumu verisi alınamadı.";
      }

      final weatherData = jsonDecode(weatherResponse.body);
      final double currentTemp = (weatherData['current']['temperature_2m'] as num).toDouble();

      return "$cityName için şu anki hava sıcaklığı: $currentTemp derece.";
    } catch (e) {
      print('Weather Service Error: $e');
      return "Hava durumu öğrenilirken bir hata oluştu.";
    }
  }
}
