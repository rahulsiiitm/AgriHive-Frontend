import 'package:flutter/material.dart';
import 'dart:ui';

class WeatherCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoadingCard();
    if (weatherData == null) return _buildErrorCard('No weather data available');

    final current = weatherData!['current'] ?? {};
    final location = weatherData!['location'] ?? 'Unknown Location';
    final coordinates = weatherData!['coordinates'];
    final forecast = weatherData!['forecast'] as List<dynamic>? ?? [];
    final error = weatherData!['error'];

    return Padding(
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
                    Column(
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
                    // Refresh Button
                    if (onRefresh != null)
                      IconButton(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Temperature and Icon Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Temp & Description
                    Column(
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
                              style: TextStyle(fontSize: 20, color: Colors.white70),
                            ),
                          ],
                        ),
                        Text(
                          current['description']?.toString().toUpperCase() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    // Weather Icon
                    Container(
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
                  ],
                ),
                const SizedBox(height: 16),

                // Details Section
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailItem(
                                  '🌡️ Feels Like',
                                  '${current['feels_like']?.toString() ?? '--'}°C',
                                ),
                              ),
                              Expanded(
                                child: _buildDetailItem(
                                  '💧 Humidity',
                                  '${current['humidity']?.toString() ?? '--'}%',
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
                                ),
                              ),
                              Expanded(
                                child: _buildDetailItem(
                                  '🌊 Pressure',
                                  '${current['pressure']?.toString() ?? '--'} hPa',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Error Section
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            error,
                            style: const TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
    );
  }

  Widget _buildLoadingCard() {
    return const Center(
      child: CircularProgressIndicator(),
    );
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
