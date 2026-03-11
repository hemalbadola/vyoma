import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  
  Future<Map<String, dynamic>> getWeather() async {
    try {
      // 1. Get Location (Permission must be handled in UI, but we try here)
      // Note: On Mac, Geolocator requires macOS permissions in Info.plist
      // Failing that, we can't get location. 
      // For now, let's try.
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {'weather_error': 'Location Disabled'};
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'weather_error': 'Location Denied'};
        }
      }

      if (permission == LocationPermission.deniedForever) {
         return {'weather_error': 'Location Denied Forever'};
      }

      Position position = await Geolocator.getCurrentPosition();

      // 2. Call OpenMeteo
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code,is_day');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        
        final temp = current['temperature_2m'];
        final code = current['weather_code'];
        final isDay = current['is_day'] == 1;
        
        return {
          'temperature': temp,
          'condition': _decodeWMO(code),
          'is_day': isDay,
          'lat': position.latitude,
          'lng': position.longitude,
          'location_source': "GPS"
        };
      } else {
        return {'weather_error': 'API Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'weather_error': e.toString()};
    }
  }

  String _decodeWMO(int code) {
    if (code == 0) return "Clear Sky";
    if (code <= 3) return "Cloudy";
    if (code <= 48) return "Fog. Visibility Low.";
    if (code <= 57) return "Drizzle. Misery.";
    if (code <= 67) return "Rain. Wet Ops.";
    if (code <= 77) return "Snow. Cold Front.";
    if (code <= 82) return "Heavy Rain. Flood Risk.";
    if (code <= 99) return "Thunderstorm. Artillery Fire.";
    return "Unknown Atmospheric Conditions";
  }
}
