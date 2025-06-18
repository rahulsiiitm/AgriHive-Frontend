import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'chatpage.dart';
import 'management.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriHive App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'lufga',
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          final user = snapshot.data as User;
          return AgriHiveNavWrapper(userId: user.uid);
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

class AgriHiveNavWrapper extends StatefulWidget {
  final String userId;
  const AgriHiveNavWrapper({super.key, required this.userId});

  @override
  _AgriHiveNavWrapperState createState() => _AgriHiveNavWrapperState();
}

class _AgriHiveNavWrapperState extends State<AgriHiveNavWrapper> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(),
      PlantationManagementPage(),
      SizedBox(), // FAB placeholder
      IoTPage(),
      ProfilePage(),
    ];
  }

  final List<IconData> _icons = [
    Icons.home,
    Icons.agriculture,
    Icons.bolt,
    Icons.person,
  ];

  final List<String> _labels = [
    'Home',
    'Manage',
    'IoT',
    'Profile',
  ];

  void _onItemTapped(int index) {
    if (index == 2) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onFabPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(userId: widget.userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_selectedIndex],
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 15),
        child: FloatingActionButton(
          onPressed: _onFabPressed,
          backgroundColor: Color(0xFF1B4332),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(Icons.eco, size: 35, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 10.0,
          color: Color(0xFF1B4332),
          elevation: 10,
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (index) {
                if (index == 2) return SizedBox(width: 40);
                final adjustedIndex = index > 2 ? index - 1 : index;

                return GestureDetector(
                  onTap: () => _onItemTapped(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _icons[adjustedIndex],
                        color: _selectedIndex == index
                            ? Color(0xFF52B788)
                            : Colors.white,
                      ),
                      SizedBox(height: 4),
                      Text(
                        _labels[adjustedIndex],
                        style: TextStyle(
                          fontFamily: 'lufga',
                          fontSize: 12,
                          color: _selectedIndex == index
                              ? Color(0xFF52B788)
                              : Colors.white,
                        ),
                      )
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// Dummy Pages (same as before)

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Text('Home Page'));
}

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Text('Profile Page'));
}

class IoTPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Text('IoT View Only'));
}
