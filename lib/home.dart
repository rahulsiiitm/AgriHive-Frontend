import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/weather/weather_card.dart'; // Update path as per your project

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String name = "Yogita";
  late final String formattedDate;
  static final DateFormat _dateFormatter = DateFormat('EEEE dd-MM-yyyy');

  final Map<String, dynamic> dummyWeatherData = {
    'location': 'Imphal',
    'coordinates': {'lat': 24.82, 'lon': 93.95},
    'current': {
      'temperature': 27,
      'feels_like': 29,
      'humidity': 60,
      'wind_speed': 3.5,
      'pressure': 1012,
      'description': 'partly cloudy',
    },
    'forecast': [],
    'error': null,
  };

  @override
  void initState() {
    super.initState();
    formattedDate = _dateFormatter.format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const _BackgroundWidget(),
          const _CurvedHeaderWidget(),
          _GreetingWidget(name: name, formattedDate: formattedDate),
          const _ProfileIconWidget(),
          _BodyContentWidget(weatherData: dummyWeatherData),
        ],
      ),
    );
  }
}

// 🔹 Background widget
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
          image: AssetImage('assets/images/background3.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      foregroundDecoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
      ),
    );
  }
}

// 🔹 Curved Header
class _CurvedHeaderWidget extends StatelessWidget {
  const _CurvedHeaderWidget();

  static const _headerGradient = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.2,
    colors: [
      Color(0xFF4B9834),
      Color(0xFF1B3713),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _BottomCurveClipper(),
      child: Container(
        height: 260,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: _headerGradient),
      ),
    );
  }
}

// 🔹 Greeting text
class _GreetingWidget extends StatelessWidget {
  final String name;
  final String formattedDate;

  const _GreetingWidget({
    required this.name,
    required this.formattedDate,
  });

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

// 🔹 Profile Icon
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

// 🔹 Body with WeatherCard
class _BodyContentWidget extends StatelessWidget {
  final Map<String, dynamic> weatherData;

  const _BodyContentWidget({required this.weatherData});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: 100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WeatherCard(
              weatherData: weatherData,
              isLoading: false,
              onRefresh: () {
                debugPrint("Weather refresh requested");
              },
            ),
            const SizedBox(height: 20),
            // Add more widgets here...
          ],
        ),
      ),
    );
  }
}

// 🔹 Curved Clip Path
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
