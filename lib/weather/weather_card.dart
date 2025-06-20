import 'package:flutter/material.dart';
import 'dart:ui';

class WeatherCard extends StatefulWidget {
  final Map<String, dynamic>? weatherData;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const WeatherCard({
    Key? key,
    required this.weatherData,
    this.onRefresh,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() {
    _slideController.forward();
    _fadeController.forward();
    _scaleController.forward();
  }

  void _onRefreshPressed() {
    _rotationController.forward().then((_) {
      _rotationController.reset();
    });
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  @override
  void didUpdateWidget(WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weatherData != oldWidget.weatherData && !widget.isLoading) {
      _slideController.reset();
      _fadeController.reset();
      _scaleController.reset();
      _startAnimations();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return _buildLoadingCard();
    if (widget.weatherData == null)
      return _buildErrorCard('No weather data available');

    final current = widget.weatherData!['current'] ?? {};
    final location = widget.weatherData!['location'] ?? 'Unknown Location';
    final coordinates = widget.weatherData!['coordinates'];
    final forecast = widget.weatherData!['forecast'] as List<dynamic>? ?? [];
    final error = widget.weatherData!['error'];

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Location Info
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(-20 * (1 - value), 0),
                              child: Opacity(
                                opacity: value,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      location,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (coordinates != null)
                                      Text(
                                        '${coordinates['lat']?.toStringAsFixed(2)}, ${coordinates['lon']?.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Refresh Button
                        if (widget.onRefresh != null)
                          AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationAnimation.value * 2 * 3.14159,
                                child: IconButton(
                                  onPressed: _onRefreshPressed,
                                  icon: const Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Temperature and Icon Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Temp & Description
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 800),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          current['temperature']?.toString() ?? '--',
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Text(
                                          '°C',
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      current['description']?.toString().toUpperCase() ??
                                          'N/A',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Weather Icon
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 1000),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: 0.8 + (0.2 * value),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _getWeatherEmoji(current['description'] ?? ''),
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Details Section
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDetailItem(
                                              '🌡️ Feels Like',
                                              '${current['feels_like']?.toString() ?? '--'}°C',
                                              const Duration(milliseconds: 1200),
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildDetailItem(
                                              '💧 Humidity',
                                              '${current['humidity']?.toString() ?? '--'}%',
                                              const Duration(milliseconds: 1400),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDetailItem(
                                              '💨 Wind',
                                              '${current['wind_speed']?.toString() ?? '--'} m/s',
                                              const Duration(milliseconds: 1600),
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildDetailItem(
                                              '🌊 Pressure',
                                              '${current['pressure']?.toString() ?? '--'} hPa',
                                              const Duration(milliseconds: 1800),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Error Section
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Opacity(
                              opacity: value,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Duration delay) {
    return TweenAnimationBuilder<double>(
      duration: delay,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorCard(String message) {
    return Center(
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }

  String _getWeatherEmoji(String description) {
    final d = description.toLowerCase();
    if (d.contains('sun')) return '☀️';
    if (d.contains('cloud')) return '☁️';
    if (d.contains('rain')) return '🌧️';
    if (d.contains('storm')) return '⛈️';
    if (d.contains('snow')) return '❄️';
    return '🌡️';
  }
}