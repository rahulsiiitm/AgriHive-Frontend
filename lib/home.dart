import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_app/weather/weather_card.dart';
import 'package:my_app/weather/weather_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  static const String name = "Yogita";
  late final String formattedDate;
  static final DateFormat _dateFormatter = DateFormat('EEEE dd-MM-yyyy');

  final WeatherService _weatherService = WeatherService();
  Map<String, dynamic> weatherData = {};
  bool isLoading = false;

  // Animation controllers
  late AnimationController _headerAnimationController;
  late AnimationController _cardsAnimationController;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _cardsFadeAnimation;

  // Cache duration - fetch new data only after this time
  static const Duration cacheValidDuration = Duration(minutes: 30);
  static const String weatherCacheKey = 'cached_weather_data';
  static const String lastFetchTimeKey = 'last_weather_fetch_time';

  // Static variable to track if animations have played
  static bool _hasAnimatedOnce = false;

  @override
  void initState() {
    super.initState();
    formattedDate = _dateFormatter.format(DateTime.now());
    
    // Initialize animations
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _cardsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: _hasAnimatedOnce ? Offset.zero : const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    ));

    _cardsFadeAnimation = Tween<double>(
      begin: _hasAnimatedOnce ? 1.0 : 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardsAnimationController,
      curve: Curves.easeIn,
    ));

    _loadWeatherData();
    _startAnimations();
  }

  void _startAnimations() {
    if (!_hasAnimatedOnce) {
      _headerAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 400), () {
        _cardsAnimationController.forward();
      });
      _hasAnimatedOnce = true;
    } else {
      // Skip animations - set to final state immediately
      _headerAnimationController.value = 1.0;
      _cardsAnimationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _cardsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadWeatherData() async {
    // Try to load cached data first
    final cachedData = await _loadCachedWeatherData();

    if (cachedData != null) {
      // Use cached data immediately
      setState(() {
        weatherData = cachedData;
        isLoading = false;
      });

      // Check if cache is still valid
      if (await _isCacheValid()) {
        return; // Cache is valid, no need to fetch new data
      }
    }

    // Cache is invalid or doesn't exist, fetch new data
    await _fetchWeatherData();
  }

  Future<Map<String, dynamic>?> _loadCachedWeatherData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataString = prefs.getString(weatherCacheKey);

      if (cachedDataString != null) {
        return json.decode(cachedDataString) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error loading cached weather data: $e');
    }
    return null;
  }

  Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchTimeString = prefs.getString(lastFetchTimeKey);

      if (lastFetchTimeString != null) {
        final lastFetchTime = DateTime.parse(lastFetchTimeString);
        final now = DateTime.now();

        return now.difference(lastFetchTime) < cacheValidDuration;
      }
    } catch (e) {
      print('Error checking cache validity: $e');
    }
    return false;
  }

  Future<void> _cacheWeatherData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(weatherCacheKey, json.encode(data));
      await prefs.setString(lastFetchTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching weather data: $e');
    }
  }

  Future<void> _fetchWeatherData() async {
    setState(() => isLoading = true);

    try {
      final data = await _weatherService.getWeather(forceRefresh: false);

      print('Received weather data: $data');

      if (data != null && data['success'] == true) {
        final transformedData = {
          'location': data['location'],
          'coordinates': data['coordinates'],
          'current': data['weather']['current'],
          'forecast': data['weather']['forecast'],
          'error': null,
        };

        // Cache the new data
        await _cacheWeatherData(transformedData);

        setState(() {
          weatherData = transformedData;
          isLoading = false;
        });
      } else {
        setState(() {
          weatherData = {'error': data?['error'] ?? 'No weather data received'};
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching weather data: $e');
      setState(() {
        weatherData = {'error': 'Failed to fetch weather data: $e'};
        isLoading = false;
      });
    }
  }

  Future<void> _refreshWeatherData() async {
    setState(() => isLoading = true);

    try {
      final data = await _weatherService.getWeather(forceRefresh: true);

      print('Refreshed weather data: $data');

      if (data != null && data['success'] == true) {
        final transformedData = {
          'location': data['location'],
          'coordinates': data['coordinates'],
          'current': data['weather']['current'],
          'forecast': data['weather']['forecast'],
          'error': null,
        };

        // Cache the refreshed data
        await _cacheWeatherData(transformedData);

        setState(() {
          weatherData = transformedData;
          isLoading = false;
        });
      } else {
        setState(() {
          weatherData = {'error': data?['error'] ?? 'No weather data received'};
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error refreshing weather data: $e');
      setState(() {
        weatherData = {'error': 'Failed to refresh weather data: $e'};
        isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const _BackgroundWidget(),
          _CurvedHeaderWidget(animation: _headerSlideAnimation),
          _GreetingWidget(name: name, formattedDate: formattedDate),
          const _ProfileIconWidget(),
          _BodyContentWidget(
            weatherData: weatherData,
            isLoading: isLoading,
            onRefresh: _refreshWeatherData,
            cardsAnimation: _cardsFadeAnimation,
          ),
        ],
      ),
    );
  }
}

// Background widget
class _BackgroundWidget extends StatelessWidget {
  const _BackgroundWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF2C5234),
        image: DecorationImage(
          image: AssetImage('assets/images/background4.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      foregroundDecoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
    );
  }
}

// Animated Curved Header
class _CurvedHeaderWidget extends StatelessWidget {
  final Animation<Offset> animation;

  const _CurvedHeaderWidget({required this.animation});

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: animation,
      child: ClipPath(
        clipper: const _BottomCurveClipper(),
        child: Container(
          height: 260,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: [Color(0xFF4B9834), Color(0xFF1B3713)],
            ),
          ),
        ),
      ),
    );
  }
}

// Greeting widget
class _GreetingWidget extends StatelessWidget {
  final String name;
  final String formattedDate;

  const _GreetingWidget({required this.name, required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 25,
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hello, $name",
            style: const TextStyle(
              fontFamily: 'lufga',
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formattedDate,
            style: const TextStyle(
              fontFamily: 'lufga',
              fontSize: 14,
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}

// Profile Icon
class _ProfileIconWidget extends StatelessWidget {
  const _ProfileIconWidget();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 40,
      right: 25,
      child: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white10,
        child: Icon(Icons.person_outline, color: Colors.white),
      ),
    );
  }
}

// Body with Animated Cards
class _BodyContentWidget extends StatelessWidget {
  final Map<String, dynamic> weatherData;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Animation<double> cardsAnimation;

  const _BodyContentWidget({
    required this.weatherData,
    required this.isLoading,
    required this.onRefresh,
    required this.cardsAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: 100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WeatherCard(
              weatherData: weatherData,
              isLoading: isLoading,
              onRefresh: onRefresh,
            ),
            const SizedBox(height: 20),

            // Animated Container Cards
            FadeTransition(
              opacity: cardsAnimation,
              child: Column(
                children: [
                  // Top row layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column (2/3 width)
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Container(
                              height: 100,
                              margin: const EdgeInsets.only(right: 8, bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE6A919),
                                  width: 1,
                                ),
                              ),
                            ),
                            Container(
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE6A919),
                                  width: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right Column (1/3 width)
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 208,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE6A919),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Bottom full-width container
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE6A919),
                        width: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Curved Clip Path
class _BottomCurveClipper extends CustomClipper<Path> {
  const _BottomCurveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 80);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 80,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}