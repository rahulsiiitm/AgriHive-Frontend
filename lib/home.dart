import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_app/weather/weather_card.dart';
import 'package:my_app/weather/weather_service.dart';

class Suggestion {
  final String category;
  final String crop;
  final String priority;
  final String text;

  Suggestion({
    required this.category,
    required this.crop,
    required this.priority,
    required this.text,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      category: json['category'],
      crop: json['crop'],
      priority: json['priority'],
      text: json['text'],
    );
  }
}

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
  List<Suggestion> suggestions = [];

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
    ).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _cardsFadeAnimation = Tween<double>(
      begin: _hasAnimatedOnce ? 1.0 : 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _cardsAnimationController, curve: Curves.easeIn),
    );

    _loadWeatherData();
    _startAnimations();
    fetchSuggestion();
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

  Future<void> fetchSuggestion() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://10.0.2.2:5000/getSuggestions?userId=user1'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      final jsonData = json.decode(response.body);

      if (jsonData['success'] == true && jsonData['suggestions'] != null) {
        final data = jsonData['suggestions'] as Map<String, dynamic>;
        final List<Suggestion> loaded = [];

        for (var key in ['first', 'second', 'third', 'fourth']) {
          if (data.containsKey(key)) {
            loaded.add(Suggestion.fromJson(data[key]));
          }
        }

        setState(() {
          suggestions = loaded;
        });
      } else {
        print("Invalid response format");
      }
    } catch (e) {
      print('Error: $e');
    }
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
            suggestions: suggestions, // 👈
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
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            formattedDate,
            style: const TextStyle(
              fontFamily: 'lufga',
              fontSize: 12,
              color: Colors.white70,
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

  final List<Suggestion> suggestions;

  const _BodyContentWidget({
    required this.weatherData,
    required this.isLoading,
    required this.onRefresh,
    required this.cardsAnimation,
    required this.suggestions,
  });

  Widget buildCategoryLabel(String category) {
    IconData icon;
    Color iconColor;

    switch (category.toLowerCase()) {
      case 'irrigation':
        icon = Icons.water_drop;
        iconColor = Colors.blue; // 💧 Blue for irrigation
        break;
      case 'pest_control':
        icon = Icons.bug_report;
        iconColor = Colors.red; // 🐞 Red for pests
        break;
      case 'protection':
        icon = Icons.shield;
        iconColor = Colors.deepPurple; // 🛡️ Purple for protection
        break;
      case 'care':
        icon = Icons.eco;
        iconColor = Colors.green; // 🌿 Green for care
        break;
      default:
        icon = Icons.info_outline;
        iconColor = Colors.orange; // default fallback
    }

    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: iconColor,
          shadows: const [
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 2,
              color: Color.fromARGB(137, 255, 255, 255),
            ),
          ],
        ),
        const SizedBox(width: 4),
        Text(
          category.toUpperCase(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: iconColor,
            shadows: const [
              Shadow(
                offset: Offset(0, 0),
                blurRadius: 12,
                color: Color.fromARGB(165, 255, 255, 255),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: 100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WeatherCard(
              weatherData: weatherData,
              isLoading: isLoading,
              onRefresh: onRefresh,
            ),
            const SizedBox(height: 10),

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
                        flex: 3,
                        child: Column(
                          children: [
                            Container(
                              height: 130,
                              margin: const EdgeInsets.only(
                                right: 8,
                                bottom: 8,
                              ),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE6A919),
                                  width: 1,
                                ),
                              ),
                              child:
                                  (suggestions.isNotEmpty)
                                      ? SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            buildCategoryLabel(
                                              suggestions[0].category,
                                            ),

                                            const SizedBox(height: 2),

                                            // Crop
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  const TextSpan(
                                                    text: 'Crop: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: suggestions[0].crop,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Priority
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  const TextSpan(
                                                    text: 'Priority: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        suggestions[0].priority,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(height: 8),

                                            // Main Suggestion Text
                                            Text(
                                              suggestions[0].text,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.normal,
                                                color: Color.fromARGB(
                                                  255,
                                                  255,
                                                  255,
                                                  255,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : const Center(
                                        child: Text(
                                          'Loading...',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                            ),

                            Container(
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE6A919),
                                  width: 1,
                                ),
                              ),
                              child:
                                  suggestions.any((s) => s.category == 'care')
                                      ? SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            buildCategoryLabel('care'),
                                            const SizedBox(height: 2),
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  const TextSpan(
                                                    text: 'Crop: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        suggestions
                                                            .firstWhere(
                                                              (s) =>
                                                                  s.category ==
                                                                  'care',
                                                            )
                                                            .crop,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  const TextSpan(
                                                    text: 'Priority: ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        suggestions
                                                            .firstWhere(
                                                              (s) =>
                                                                  s.category ==
                                                                  'care',
                                                            )
                                                            .priority,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              suggestions
                                                  .firstWhere(
                                                    (s) => s.category == 'care',
                                                  )
                                                  .text,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.normal,
                                                color: Color.fromARGB(
                                                  255,
                                                  255,
                                                  255,
                                                  255,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : const Center(
                                        child: Text(
                                          'Loading...',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                            ),
                          ],
                        ),
                      ),

                      // Right Column (1/3 width)
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 238, // ✅ Increased by 30px
                          margin: const EdgeInsets.only(left: 0),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE6A919),
                              width: 1,
                            ),
                          ),
                          child:
                              suggestions.any((s) => s.category == 'protection')
                                  ? SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        buildCategoryLabel('protection'),

                                        const SizedBox(height: 2),

                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Crop: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    suggestions
                                                        .firstWhere(
                                                          (s) =>
                                                              s.category ==
                                                              'protection',
                                                        )
                                                        .crop,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Priority: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    suggestions
                                                        .firstWhere(
                                                          (s) =>
                                                              s.category ==
                                                              'protection',
                                                        )
                                                        .priority,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        Text(
                                          suggestions
                                              .firstWhere(
                                                (s) =>
                                                    s.category == 'protection',
                                              )
                                              .text,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.normal,
                                            color: Color.fromARGB(
                                              255,
                                              255,
                                              255,
                                              255,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : const Center(
                                    child: Text(
                                      'Loading...',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Bottom full-width container
                  Container(
                    height: 100,
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE6A919),
                        width: 1,
                      ),
                    ),
                    child:
                        (suggestions.isNotEmpty)
                            ? SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildCategoryLabel(
                                    suggestions[3].category,
                                  ), // Use index or filter by category

                                  const SizedBox(height: 2),

                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'Crop: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        TextSpan(
                                          text: suggestions[3].crop,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'Priority: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        TextSpan(
                                          text: suggestions[3].priority,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    suggestions[3].text,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                      color: Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : const Center(
                              child: Text(
                                'Loading...',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
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
