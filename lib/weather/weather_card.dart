// weather_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    if (isLoading) {
      return _buildLoadingCard();
    }

    if (weatherData == null) {
      return _buildErrorCard('No weather data available');
    }

    final current = weatherData!['current'] ?? {};
    final location = weatherData!['location'] ?? 'Unknown Location';
    final coordinates = weatherData!['coordinates'];
    final forecast = weatherData!['forecast'] as List<dynamic>? ?? [];
    final error = weatherData!['error'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main weather card
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getGradientColors(current['description']?.toString() ?? ''),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with location and refresh button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (coordinates != null)
                              Text(
                                '${coordinates['lat']?.toStringAsFixed(2)}, ${coordinates['lon']?.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (onRefresh != null)
                        IconButton(
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          tooltip: 'Refresh Weather',
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Main temperature display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${current['temperature']?.toString() ?? '--'}',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                '°C',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            current['description']?.toString().toUpperCase() ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      // Weather icon (you can replace with actual weather icons)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _getWeatherEmoji(current['description']?.toString() ?? ''),
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Weather details grid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailItem(
                                '💨 Wind Speed',
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
                  
                  // Error message if any
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
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
          
          // Forecast card
          if (forecast.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📅 24-Hour Forecast',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: forecast.length,
                        itemBuilder: (context, index) {
                          final item = forecast[index];
                          return _buildForecastItem(item);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(20),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading weather data...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (onRefresh != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildForecastItem(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['date']?.toString() ?? '');
    final timeStr = date != null ? DateFormat('HH:mm').format(date) : 'N/A';
    final temp = item['temp']?.toString() ?? '--';
    final description = item['description']?.toString() ?? '';
    final rain = item['rain']?.toString() ?? '0';

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _getWeatherEmoji(description),
            style: const TextStyle(fontSize: 24),
          ),
          Text(
            '${temp}°',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (rain != '0')
            Text(
              '💧${rain}mm',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade600,
              ),
            ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('clear') || desc.contains('sunny')) {
      return [Colors.orange.shade400, Colors.deepOrange.shade600];
    } else if (desc.contains('cloud')) {
      return [Colors.grey.shade400, Colors.grey.shade600];
    } else if (desc.contains('rain') || desc.contains('shower')) {
      return [Colors.blue.shade400, Colors.blue.shade600];
    } else if (desc.contains('thunder')) {
      return [Colors.purple.shade400, Colors.purple.shade700];
    } else if (desc.contains('snow')) {
      return [Colors.lightBlue.shade200, Colors.lightBlue.shade400];
    } else {
      return [Colors.teal.shade400, Colors.teal.shade600];
    }
  }

  String _getWeatherEmoji(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('clear') || desc.contains('sunny')) return '☀️';
    if (desc.contains('few clouds')) return '🌤️';
    if (desc.contains('scattered clouds')) return '⛅';
    if (desc.contains('broken clouds') || desc.contains('overcast')) return '☁️';
    if (desc.contains('shower rain')) return '🌦️';
    if (desc.contains('rain')) return '🌧️';
    if (desc.contains('thunderstorm')) return '⛈️';
    if (desc.contains('snow')) return '🌨️';
    if (desc.contains('mist') || desc.contains('fog')) return '🌫️';
    return '🌤️'; // default
  }
}