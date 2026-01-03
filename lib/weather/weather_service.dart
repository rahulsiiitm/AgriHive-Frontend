// weather_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:geocoding/geocoding.dart';

class WeatherService {
  static const String baseUrl =
      'https://agrihive-server91.onrender.com/weather';
  static const int timeoutSeconds = 10;
  static const int cacheExpiryHours = 1;

  // Cache keys
  static const String _weatherDataKey = 'weather_data';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const String _cachedLatKey = 'cached_lat';
  static const String _cachedLonKey = 'cached_lon';

  // In-memory cache for current session
  Map<String, dynamic>? _memoryCache;
  DateTime? _memoryCacheTimestamp;
  double? _memoryCacheLat;
  double? _memoryCacheLon;

  Future<Position?> getCurrentLocation() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWeather({
    double? lat,
    double? lon,
    required bool forceRefresh,
  }) async {
    double? latitude = lat;
    double? longitude = lon;

    // If no coordinates provided, get current location
    if (latitude == null || longitude == null) {
      final position = await getCurrentLocation();
      if (position != null) {
        latitude = position.latitude;
        longitude = position.longitude;
      } else {
        // Fallback to default location (Agra)
        latitude = 27.1767;
        longitude = 78.0081;
        print('Using default location: Agra');
      }
    }

    // Check if we should use cached data
    if (!forceRefresh) {
      final cachedData = await _getCachedWeather(latitude, longitude);
      if (cachedData != null) {
        print('Using cached weather data');
        return cachedData;
      }
    }

    // Fetch fresh data
    return await _fetchAndCacheWeather(latitude, longitude);
  }

  Future<Map<String, dynamic>?> _getCachedWeather(
    double lat,
    double lon,
  ) async {
    try {
      // First check in-memory cache
      if (_isMemoryCacheValid(lat, lon)) {
        print('Using in-memory cache');
        return _memoryCache;
      }

      // Then check persistent storage
      final prefs = await SharedPreferences.getInstance();

      // Check if we have cached data
      final cachedDataString = prefs.getString(_weatherDataKey);
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);
      final cachedLat = prefs.getDouble(_cachedLatKey);
      final cachedLon = prefs.getDouble(_cachedLonKey);

      if (cachedDataString != null &&
          cacheTimestamp != null &&
          cachedLat != null &&
          cachedLon != null) {
        // Check if cache is still valid (within 1 hour and same location)
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
        final now = DateTime.now();
        final timeDifference = now.difference(cacheTime);

        // Check if location is approximately the same (within ~1km)
        final locationDifference = _calculateDistance(
          lat,
          lon,
          cachedLat,
          cachedLon,
        );

        if (timeDifference.inHours < cacheExpiryHours &&
            locationDifference < 1.0) {
          final cachedData =
              json.decode(cachedDataString) as Map<String, dynamic>;

          // Update in-memory cache
          _memoryCache = cachedData;
          _memoryCacheTimestamp = cacheTime;
          _memoryCacheLat = cachedLat;
          _memoryCacheLon = cachedLon;

          print(
            'Using persistent cache (${timeDifference.inMinutes} minutes old)',
          );
          return cachedData;
        } else {
          print('Cache expired or location changed, fetching fresh data');
        }
      }
    } catch (e) {
      print('Error reading cache: $e');
    }

    return null;
  }

  Future<Map<String, dynamic>?> _fetchAndCacheWeather(
    double lat,
    double lon,
  ) async {
    Map<String, dynamic>? weatherData;

    try {
      final response = await http
          .get(Uri.parse('$baseUrl?lat=$lat&lon=$lon'))
          .timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        weatherData = json.decode(response.body);
        print('Fetched fresh weather data from API');

        // --- NEW: Get Real Location Name ---
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            // Uses Locality (City) or SubAdministrativeArea (District)
            String realName =
                place.locality ??
                place.subAdministrativeArea ??
                'Unknown Location';
            weatherData?['location'] = realName;
          } else {
            weatherData?['location'] = _getLocationName(
              lat,
              lon,
            ); // Fallback to hardcoded
          }
        } catch (e) {
          print('Geocoding error: $e');
          weatherData?['location'] = _getLocationName(
            lat,
            lon,
          ); // Fallback to hardcoded
        }
        // -----------------------------------

        weatherData?['coordinates'] = {'lat': lat, 'lon': lon};
      } else {
        throw Exception('API returned ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Weather API error: $e');
      weatherData = _getDummyData(lat, lon);
    }

    // Cache the data if we got it
    if (weatherData != null) {
      await _cacheWeatherData(weatherData, lat, lon);
    }

    return weatherData;
  }

  Future<void> _cacheWeatherData(
    Map<String, dynamic> data,
    double lat,
    double lon,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Store in persistent storage
      await prefs.setString(_weatherDataKey, json.encode(data));
      await prefs.setInt(_cacheTimestampKey, now.millisecondsSinceEpoch);
      await prefs.setDouble(_cachedLatKey, lat);
      await prefs.setDouble(_cachedLonKey, lon);

      // Update in-memory cache
      _memoryCache = data;
      _memoryCacheTimestamp = now;
      _memoryCacheLat = lat;
      _memoryCacheLon = lon;

      print('Weather data cached successfully');
    } catch (e) {
      print('Error caching weather data: $e');
    }
  }

  bool _isMemoryCacheValid(double lat, double lon) {
    if (_memoryCache == null ||
        _memoryCacheTimestamp == null ||
        _memoryCacheLat == null ||
        _memoryCacheLon == null) {
      return false;
    }

    final now = DateTime.now();
    final timeDifference = now.difference(_memoryCacheTimestamp!);
    final locationDifference = _calculateDistance(
      lat,
      lon,
      _memoryCacheLat!,
      _memoryCacheLon!,
    );

    return timeDifference.inHours < cacheExpiryHours &&
        locationDifference < 1.0;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Simple distance calculation using Haversine formula
    const double earthRadius = 6371; // km

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Map<String, dynamic> _getDummyData(double lat, double lon) {
    // Generate location name based on coordinates
    String locationName = _getLocationName(lat, lon);

    // Generate dummy forecast data (next 24 hours in 3-hour intervals)
    List<Map<String, dynamic>> dummyForecast = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < 8; i++) {
      DateTime forecastTime = now.add(Duration(hours: i * 3));
      dummyForecast.add({
        'date': forecastTime.toIso8601String(),
        'temp': (18 + (lat.abs() % 10) + (i % 5)).toDouble(),
        'humidity': (45 + (lon.abs() % 25) + (i % 15)).round(),
        'description': _getWeatherDescription(lat + i),
        'rain':
            (i % 3 == 0)
                ? (math.Random().nextDouble() * 2).toStringAsFixed(1)
                : '0',
      });
    }

    return {
      'location': locationName,
      'coordinates': {'lat': lat, 'lon': lon},
      'current': {
        'temperature': (20 + (lat.abs() % 15)).toDouble(),
        'humidity': (50 + (lon.abs() % 30)).round(),
        'description': _getWeatherDescription(lat),
        'wind_speed': (2 + (lat.abs() % 5)).toDouble(),
        'pressure': (1010 + (lat.abs() % 20)).round(),
        'feels_like': (22 + (lat.abs() % 12)).toDouble(),
      },
      'forecast': dummyForecast,
      'error': 'Using demo data - API unavailable',
    };
  }

  String _getLocationName(double lat, double lon) {
    // Enhanced location detection based on coordinates
    if (lat >= 28.4 && lat <= 28.8 && lon >= 77.0 && lon <= 77.4) {
      return 'Delhi';
    } else if (lat >= 19.0 && lat <= 19.3 && lon >= 72.7 && lon <= 73.0) {
      return 'Mumbai';
    } else if (lat >= 12.8 && lat <= 13.1 && lon >= 77.5 && lon <= 77.7) {
      return 'Bangalore';
    } else if (lat >= 27.1 && lat <= 27.2 && lon >= 78.0 && lon <= 78.1) {
      return 'Agra';
    } else if (lat >= 22.5 && lat <= 22.6 && lon >= 88.3 && lon <= 88.4) {
      return 'Kolkata';
    } else if (lat >= 13.0 && lat <= 13.1 && lon >= 80.2 && lon <= 80.3) {
      return 'Chennai';
    } else if (lat >= 17.3 && lat <= 17.5 && lon >= 78.4 && lon <= 78.5) {
      return 'Hyderabad';
    } else if (lat >= 18.4 && lat <= 18.6 && lon >= 73.8 && lon <= 73.9) {
      return 'Pune';
    } else if (lat >= 23.0 && lat <= 23.1 && lon >= 72.5 && lon <= 72.6) {
      return 'Ahmedabad';
    } else if (lat >= 25 && lat <= 30 && lon >= 75 && lon <= 85) {
      return 'Northern India';
    } else if (lat >= 20 && lat <= 25 && lon >= 70 && lon <= 85) {
      return 'Central India';
    } else if (lat >= 8 && lat <= 20 && lon >= 70 && lon <= 85) {
      return 'Southern India';
    } else {
      return 'Location (${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)})';
    }
  }

  String _getWeatherDescription(double lat) {
    final descriptions = [
      'clear sky',
      'few clouds',
      'scattered clouds',
      'broken clouds',
      'shower rain',
      'rain',
      'thunderstorm',
      'snow',
      'mist',
      'overcast clouds',
    ];
    return descriptions[(lat.abs() % descriptions.length).floor()];
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear persistent cache
      await prefs.remove(_weatherDataKey);
      await prefs.remove(_cacheTimestampKey);
      await prefs.remove(_cachedLatKey);
      await prefs.remove(_cachedLonKey);

      // Clear in-memory cache
      _memoryCache = null;
      _memoryCacheTimestamp = null;
      _memoryCacheLat = null;
      _memoryCacheLon = null;

      print('Cache cleared successfully');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Helper method to check cache status
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);

      if (cacheTimestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
        final now = DateTime.now();
        final ageInMinutes = now.difference(cacheTime).inMinutes;

        return {
          'hasCachedData': true,
          'cacheAge': ageInMinutes,
          'isExpired': ageInMinutes >= (cacheExpiryHours * 60),
          'cacheTime': cacheTime.toIso8601String(),
        };
      }
    } catch (e) {
      print('Error getting cache info: $e');
    }

    return {
      'hasCachedData': false,
      'cacheAge': 0,
      'isExpired': true,
      'cacheTime': null,
    };
  }

  // Helper methods to access specific data
  Map<String, dynamic>? getCurrentWeather(Map<String, dynamic>? weatherData) {
    return weatherData?['current'];
  }

  List<Map<String, dynamic>>? getForecast(Map<String, dynamic>? weatherData) {
    if (weatherData?['forecast'] != null) {
      return List<Map<String, dynamic>>.from(weatherData!['forecast']);
    }
    return null;
  }

  String? getLocation(Map<String, dynamic>? weatherData) {
    return weatherData?['location'];
  }

  Map<String, dynamic>? getCoordinates(Map<String, dynamic>? weatherData) {
    return weatherData?['coordinates'];
  }

  bool hasError(Map<String, dynamic>? weatherData) {
    return weatherData?['error'] != null;
  }

  String? getError(Map<String, dynamic>? weatherData) {
    return weatherData?['error'];
  }
}
