import 'package:flutter/material.dart';
import '../screens/login_screen.dart'; // Import your login screen

class GetStartedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background6.jpg', // Your background image
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay for text visibility
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 35.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Spacer(flex: 3),

                  Text(
                    "Grow more, worry less",
                    style: TextStyle(
                      fontFamily: 'lufga',
                      fontSize: 22,
                      color: const Color.fromARGB(255, 0, 0, 0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        colors: [
                          Color(0xFFFF9933), // Saffron
                          Colors.white, // White (center)
                          Color(0xFF138808), // Green
                          Color.fromARGB(
                            255,
                            8,
                            60,
                            3,
                          ), // Green (repeated for emphasis)
                          Color.fromARGB(
                            255,
                            0,
                            0,
                            0,
                          ), // Green (repeated for emphasis)
                          Colors.black, // Black (repeated for emphasis)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      "let’s get back to your fields.",
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'lufga',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  Center(
                    child: Image.asset(
                      'assets/images/path1.png', // Your green line plant icon
                      height: 150,
                    ),
                  ),

                  Spacer(flex: 5),

                  // Get Started button
                  Center(
                    child: ElevatedButton(
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LoginScreen()),
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(154, 255, 179, 0),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: const Color.fromARGB(255, 255, 179, 0)),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 14,
                        ),
                        elevation: 8,
                      ),
                      child: Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontFamily: 'lufga',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
