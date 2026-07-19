import 'lib/weather_service.dart';

void main() async {
  print('Testing weather service for Istanbul...');
  final result = await WeatherService.getWeather('Istanbul');
  print('Result: ' + result);
}
