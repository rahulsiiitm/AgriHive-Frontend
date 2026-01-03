import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_app/weather/weather_card.dart';
import 'package:my_app/weather/weather_service.dart';

// Models
class Suggestion {
  final String category;
  final String crop;
  final String priority;
  final String text;

  const Suggestion({
    required this.category,
    required this.crop,
    required this.priority,
    required this.text,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      category: json['category'] ?? '',
      crop: json['crop'] ?? '',
      priority: json['priority'] ?? '',
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'crop': crop,
      'priority': priority,
      'text': text,
    };
  }
}

class _CategoryData {
  final IconData icon;
  final Color color;

  const _CategoryData(this.icon, this.color);
}

// Constants
class _Constants {
  // 1. Reduced cache duration (so it checks for updates more often)
  static const Duration cacheValidDuration = Duration(minutes: 5);

  static const Duration headerAnimationDuration = Duration(milliseconds: 800);
  static const Duration cardsAnimationDuration = Duration(milliseconds: 600);
  static const Duration animationDelay = Duration(milliseconds: 500);

  // 2. INCREASED TIMEOUT to 60 seconds (AI needs time!)
  static const Duration apiTimeout = Duration(seconds: 60);

  // Cache keys...
  static const String weatherCacheKey = 'cached_weather_data';
  static const String lastFetchTimeKey = 'last_weather_fetch_time';
  static const String suggestionsCacheKey = 'cached_suggestions_data';
  static const String lastSuggestionsFetchTimeKey =
      'last_suggestions_fetch_time';
  static const String userNameCacheKey = 'cached_user_name';
  static const String lastUserFetchTimeKey = 'last_user_fetch_time';

  // Category config...
  static const Map<String, _CategoryData> categoryConfig = {
    'irrigation': _CategoryData(Icons.water_drop, Colors.blue),
    'pest_control': _CategoryData(Icons.bug_report, Colors.red),
    'protection': _CategoryData(Icons.shield, Color.fromARGB(255, 0, 187, 255)),
    'care': _CategoryData(Icons.eco, Colors.green),
  };
}

// Services
class _CacheService {
  static Future<void> cacheData(String key, String data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, data);
    } catch (e) {
      debugPrint('Error caching data for key $key: $e');
    }
  }

  static Future<String?> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      debugPrint('Error getting cached data for key $key: $e');
      return null;
    }
  }

  static Future<void> setCacheTimestamp(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error setting cache timestamp for key $key: $e');
    }
  }

  static Future<bool> isCacheValid(String timestampKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString(timestampKey);

      if (timestampString != null) {
        final timestamp = DateTime.parse(timestampString);
        return DateTime.now().difference(timestamp) <
            _Constants.cacheValidDuration;
      }
    } catch (e) {
      debugPrint('Error checking cache validity for key $timestampKey: $e');
    }
    return false;
  }
}

class _SuggestionsService {
  static Future<List<Suggestion>> fetchSuggestions(String userId) async {
    try {
      debugPrint('🌱 Fetching suggestions for $userId...'); // Debug log

      final response = await http
          .get(
            Uri.parse(
              'https://agrihive-server91.onrender.com/getSuggestions?userId=$userId',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_Constants.apiTimeout); // Uses new 60s timeout

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true && jsonData['suggestions'] != null) {
          debugPrint('✅ Suggestions fetched successfully');
          return _parseSuggestions(jsonData['suggestions']);
        } else {
          throw Exception('Invalid response format or success=false');
        }
      } else {
        throw HttpException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching suggestions: $e');
      rethrow; // Pass error up to show fallback
    }
  }

  static List<Suggestion> _parseSuggestions(Map<String, dynamic> data) {
    final suggestions = <Suggestion>[];

    for (var key in ['first', 'second', 'third', 'fourth']) {
      if (data.containsKey(key)) {
        suggestions.add(Suggestion.fromJson(data[key]));
      }
    }

    return suggestions;
  }

  static List<Suggestion> getMockSuggestions() {
    return [
      const Suggestion(
        category: 'irrigation',
        crop: 'Wheat',
        priority: 'High',
        text:
            'Water your wheat crop early morning. Soil moisture should be maintained at 70%.',
      ),
      const Suggestion(
        category: 'care',
        crop: 'Rice',
        priority: 'Medium',
        text: 'Apply organic fertilizer. Monitor for any yellowing of leaves.',
      ),
      const Suggestion(
        category: 'protection',
        crop: 'Tomato',
        priority: 'High',
        text: 'Inspect plants for pest damage. Use neem oil spray if needed.',
      ),
      const Suggestion(
        category: 'pest_control',
        crop: 'Cotton',
        priority: 'Medium',
        text:
            'Check for bollworm infestation. Apply biological pesticide if required.',
      ),
    ];
  }
}

class _UserService {
  static Future<String> fetchUserName(String userId) async {
    try {
      final response = await http
          .get(
            // ✅ FIX: Changed 'http' to 'https'
            Uri.parse(
              'https://agrihive-server91.onrender.com/get_farmer_profile?userId=$userId&field=name',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_Constants.apiTimeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData.containsKey('name')) {
          String fullName = jsonData['name'] ?? 'User';
          return fullName.split(' ').first;
        } else {
          throw Exception('Name field not found in response');
        }
      } else {
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching user name: $e');
      return 'User';
    }
  }
}

// Main HomePage Widget
class HomePage extends StatefulWidget {
  final dynamic userId;

  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();

  // State variables
  Map<String, dynamic> weatherData = {};
  bool isLoading = false;
  List<Suggestion> suggestions = [];
  Map<String, Suggestion> _suggestionsByCategory = {};
  String userName = 'User';

  // Animation controllers
  late AnimationController _headerAnimationController;
  late AnimationController _cardsAnimationController;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _cardsFadeAnimation;

  static bool _hasAnimatedOnce = false;

  late final String formattedDate;

  @override
  void initState() {
    super.initState();
    formattedDate = DateFormat('EEEE dd-MM-yyyy').format(DateTime.now());
    _initializeAnimations();
    _loadAllData();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _cardsAnimationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _headerAnimationController = AnimationController(
      duration: _Constants.headerAnimationDuration,
      vsync: this,
    );

    _cardsAnimationController = AnimationController(
      duration: _Constants.cardsAnimationDuration,
      vsync: this,
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: _hasAnimatedOnce ? Offset.zero : const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOut, // More noticeable curve
      ),
    );

    _cardsFadeAnimation = Tween<double>(
      begin: _hasAnimatedOnce ? 1.0 : 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _cardsAnimationController,
        curve: Curves.easeInOut, // Smoother curve
      ),
    );

    _startAnimations();
  }

  void _startAnimations() {
    if (!_hasAnimatedOnce) {
      _headerAnimationController.forward();
      Future.delayed(_Constants.animationDelay, () {
        if (mounted) _cardsAnimationController.forward();
      });
      _hasAnimatedOnce = true;
    } else {
      _headerAnimationController.value = 1.0;
      _cardsAnimationController.value = 1.0;
    }
  }

  void _loadAllData() {
    Future.wait([
      _loadUserName(),
      _loadWeatherData(),
      _loadSuggestionsData(),
      // ignore: body_might_complete_normally_catch_error
    ]).catchError((error) {
      debugPrint('Error loading data: $error');
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _fetchUserName(),
      _refreshWeatherData(),
      _fetchSuggestions(),
    ]);
  }

  // User name methods
  Future<void> _loadUserName() async {
    final cachedName = await _CacheService.getCachedData(
      _Constants.userNameCacheKey,
    );
    final isCacheValid = await _CacheService.isCacheValid(
      _Constants.lastUserFetchTimeKey,
    );

    if (cachedName != null && cachedName.isNotEmpty) {
      if (mounted) {
        setState(() {
          userName = cachedName;
        });
      }
      if (isCacheValid) return;
    }

    await _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    try {
      final fetchedName = await _UserService.fetchUserName(
        widget.userId.toString(),
      );

      await Future.wait([
        _CacheService.cacheData(_Constants.userNameCacheKey, fetchedName),
        _CacheService.setCacheTimestamp(_Constants.lastUserFetchTimeKey),
      ]);

      if (mounted) {
        setState(() {
          userName = fetchedName;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
  }

  // Weather data methods
  Future<void> _loadWeatherData() async {
    final cachedData = await _loadCachedWeatherData();
    final isCacheValid = await _CacheService.isCacheValid(
      _Constants.lastFetchTimeKey,
    );

    if (cachedData != null) {
      if (mounted) {
        setState(() {
          weatherData = cachedData;
          isLoading = false;
        });
      }
      if (isCacheValid) return;
    }

    await _fetchWeatherData();
  }

  Future<Map<String, dynamic>?> _loadCachedWeatherData() async {
    try {
      final cachedDataString = await _CacheService.getCachedData(
        _Constants.weatherCacheKey,
      );
      if (cachedDataString != null) {
        return json.decode(cachedDataString) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading cached weather data: $e');
    }
    return null;
  }

  Future<void> _fetchWeatherData() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final data = await _weatherService.getWeather(forceRefresh: false);

      if (data != null && data['success'] == true) {
        final transformedData = {
          'location': data['location'],
          'coordinates': data['coordinates'],
          'current': data['weather']['current'],
          'forecast': data['weather']['forecast'],
          'error': null,
        };

        await Future.wait([
          _CacheService.cacheData(
            _Constants.weatherCacheKey,
            json.encode(transformedData),
          ),
          _CacheService.setCacheTimestamp(_Constants.lastFetchTimeKey),
        ]);

        if (mounted) {
          setState(() {
            weatherData = transformedData;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            weatherData = {
              'error': data?['error'] ?? 'No weather data received',
            };
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching weather data: $e');
      if (mounted) {
        setState(() {
          weatherData = {'error': 'Failed to fetch weather data: $e'};
          isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshWeatherData() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final data = await _weatherService.getWeather(forceRefresh: true);

      if (data != null && data['success'] == true) {
        final transformedData = {
          'location': data['location'],
          'coordinates': data['coordinates'],
          'current': data['weather']['current'],
          'forecast': data['weather']['forecast'],
          'error': null,
        };

        await Future.wait([
          _CacheService.cacheData(
            _Constants.weatherCacheKey,
            json.encode(transformedData),
          ),
          _CacheService.setCacheTimestamp(_Constants.lastFetchTimeKey),
        ]);

        if (mounted) {
          setState(() {
            weatherData = transformedData;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing weather data: $e');
      if (mounted) {
        setState(() {
          weatherData = {'error': 'Failed to refresh weather data: $e'};
          isLoading = false;
        });
      }
    }
  }

  // Suggestions data methods
  Future<void> _loadSuggestionsData() async {
    final cachedSuggestions = await _loadCachedSuggestions();
    final isCacheValid = await _CacheService.isCacheValid(
      _Constants.lastSuggestionsFetchTimeKey,
    );

    if (cachedSuggestions != null && cachedSuggestions.isNotEmpty) {
      _updateSuggestionsState(cachedSuggestions);
    }
    if (isCacheValid) return;
    await _fetchSuggestions();
  }

  Future<List<Suggestion>?> _loadCachedSuggestions() async {
    try {
      final cachedString = await _CacheService.getCachedData(
        _Constants.suggestionsCacheKey,
      );
      if (cachedString != null) {
        final jsonList = json.decode(cachedString) as List<dynamic>;
        return jsonList
            .map((json) => Suggestion.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading cached suggestions: $e');
    }
    return null;
  }

  Future<void> _fetchSuggestions() async {
    try {
      final fetchedSuggestions = await _SuggestionsService.fetchSuggestions(
        widget.userId.toString(),
      );
      await _cacheSuggestions(fetchedSuggestions);
      _updateSuggestionsState(fetchedSuggestions);
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');

      if (suggestions.isEmpty) {
        debugPrint('🔄 Falling back to mock data because list is empty');
        final mockSuggestions = _SuggestionsService.getMockSuggestions();
        _updateSuggestionsState(mockSuggestions);
      }
    }
  }

  void _updateSuggestionsState(List<Suggestion> newSuggestions) {
    final categoryMap = <String, Suggestion>{};
    for (var suggestion in newSuggestions) {
      categoryMap[suggestion.category] = suggestion;
    }

    if (mounted) {
      setState(() {
        suggestions = newSuggestions;
        _suggestionsByCategory = categoryMap;
      });
    }
  }

  Future<void> _cacheSuggestions(List<Suggestion> suggestions) async {
    try {
      final jsonList = suggestions.map((s) => s.toJson()).toList();
      await Future.wait([
        _CacheService.cacheData(
          _Constants.suggestionsCacheKey,
          json.encode(jsonList),
        ),
        _CacheService.setCacheTimestamp(_Constants.lastSuggestionsFetchTimeKey),
      ]);
    } catch (e) {
      debugPrint('Error caching suggestions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Stack(
          children: [
            const _BackgroundWidget(),
            _CurvedHeaderWidget(animation: _headerSlideAnimation),
            _GreetingWidget(name: userName, formattedDate: formattedDate),
            const _ProfileIconWidget(),
            _BodyContentWidget(
              weatherData: weatherData,
              isLoading: isLoading,
              cardsAnimation: _cardsFadeAnimation,
              suggestions: suggestions,
              suggestionsByCategory: _suggestionsByCategory,
            ),
          ],
        ),
      ),
    );
  }
}

// UI Components
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

class _BodyContentWidget extends StatelessWidget {
  final Map<String, dynamic> weatherData;
  final bool isLoading;
  final Animation<double> cardsAnimation;
  final List<Suggestion> suggestions;
  final Map<String, Suggestion> suggestionsByCategory;

  const _BodyContentWidget({
    required this.weatherData,
    required this.isLoading,
    required this.cardsAnimation,
    required this.suggestions,
    required this.suggestionsByCategory,
  });

  Widget _buildCategoryLabel(String category) {
    final config =
        _Constants.categoryConfig[category.toLowerCase()] ??
        const _CategoryData(Icons.info_outline, Colors.orange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: 12,
            color: config.color,
            shadows: const [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3,
                color: Colors.black54,
              ),
            ],
          ),
          const SizedBox(width: 4),
          Text(
            category.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard({
    required Suggestion? suggestion,
    required double height,
    EdgeInsets? margin,
  }) {
    return Container(
      height: height,
      margin: margin ?? EdgeInsets.zero,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6A919), width: 1),
      ),
      child:
          suggestion != null
              ? _SuggestionContent(
                suggestion: suggestion,
                buildCategoryLabel: _buildCategoryLabel,
              )
              : const Center(
                child: Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: 100,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WeatherCard(weatherData: weatherData, isLoading: isLoading),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: cardsAnimation,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildSuggestionCard(
                              suggestion:
                                  suggestions.isNotEmpty
                                      ? suggestions[0]
                                      : null,
                              height: 130,
                              margin: const EdgeInsets.only(
                                right: 8,
                                bottom: 8,
                              ),
                            ),
                            _buildSuggestionCard(
                              suggestion: suggestionsByCategory['care'],
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildSuggestionCard(
                          suggestion: suggestionsByCategory['protection'],
                          height: 238,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildSuggestionCard(
                    suggestion: suggestions.length > 3 ? suggestions[3] : null,
                    height: 100,
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

class _SuggestionContent extends StatelessWidget {
  final Suggestion suggestion;
  final Widget Function(String) buildCategoryLabel;

  const _SuggestionContent({
    required this.suggestion,
    required this.buildCategoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildCategoryLabel(suggestion.category),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Crop: ', suggestion.crop),
              const SizedBox(height: 4),
              _buildInfoRow('Priority: ', suggestion.priority),
              const SizedBox(height: 8),
              Text(
                suggestion.text,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 1.3,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
