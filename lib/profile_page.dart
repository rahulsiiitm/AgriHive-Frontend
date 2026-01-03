import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _notificationsEnabled = true;
  late String userId;
  Map<String, dynamic>? profileData;
  final String apiBaseUrl = 'https://agrihive-server91.onrender.com';

  // Cache variables
  static Map<String, dynamic>? _cachedProfileData;
  static DateTime? _lastLoadTime;
  static const Duration _cacheValidDuration = Duration(minutes: 30);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'user1';
    _loadProfileFromCache();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  void _loadProfileFromCache() {
    if (_cachedProfileData != null &&
        _lastLoadTime != null &&
        DateTime.now().difference(_lastLoadTime!) < _cacheValidDuration) {
      setState(() {
        profileData = _cachedProfileData;
      });
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/get_farmer_profile?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final newProfileData = json.decode(response.body)['profile'];
        setState(() {
          profileData = newProfileData;
          _cachedProfileData = newProfileData;
          _lastLoadTime = DateTime.now();
        });
      } else if (response.statusCode == 404) {
        setState(() {
          profileData = {
            'name': 'No data',
            'location': 'No data',
            'phone': '',
            'language': 'English',
            'profilePhoto': null,
          };
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load profile');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    try {
      if (updates.containsKey('language')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_language', updates['language']);
      }

      print('🔵 Sending update request for userId: $userId');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/update_farmer_profile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'updates': updates}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          profileData = {...?profileData, ...updates};
          _cachedProfileData = profileData;
          _lastLoadTime = DateTime.now();
        });
        return true;
      }
      return false;
    } catch (e) {
      print('🔴 Exception in updateProfile: $e');
      return false;
    }
  }

  Future<bool> uploadPhoto(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/upload_profile_photo'),
      );
      request.fields['userId'] = userId;
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ),
      );
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _performLogout() async {
    try {
      _cachedProfileData = null;
      _lastLoadTime = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      _showSnackBar('Logout failed. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body:
          profileData == null
              ? Center(
                child: CircularProgressIndicator(color: Colors.green[600]),
              )
              : RefreshIndicator(
                color: Colors.green[600],
                onRefresh: () => _loadProfile(forceRefresh: true),
                child: CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          SizedBox(height: 16),
                          _buildMenuItems(),
                          SizedBox(height: 20),
                          Container(height: 100, color: Colors.transparent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 260,
      floating: false,
      pinned: true,
      backgroundColor: Colors.grey[100],
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            image: DecorationImage(
              image: AssetImage('assets/images/rice.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.3),
                BlendMode.darken,
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40),
                  _buildProfileAvatar(),
                  SizedBox(height: 20),
                  Text(
                    profileData!['name'] ?? 'Name',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Colors.white.withOpacity(0.9),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          profileData!['location'] ?? 'Location',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  if (profileData!['phone'] != null &&
                      profileData!['phone'].toString().isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          color: Colors.white.withOpacity(0.8),
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          profileData!['phone'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
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
  }

  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child:
                profileData!['profilePhoto'] != null
                    ? ClipOval(
                      child: Image.network(
                        profileData!['profilePhoto'],
                        fit: BoxFit.cover,
                        width: 70,
                        height: 70,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person_outline,
                            size: 40,
                            color: Colors.green[600],
                          );
                        },
                      ),
                    )
                    : Icon(
                      Icons.person_outline,
                      size: 40,
                      color: Colors.green[600],
                    ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 14,
                color: Colors.green[600],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItems() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildMenuSection('Account', [
            _buildMenuItem(Icons.edit_outlined, 'Edit Profile', _editProfile),
            _buildMenuItem(
              Icons.notifications_outlined,
              'Notifications',
              _showNotifications,
            ),
            _buildMenuItem(Icons.language_outlined, 'Language', _showLanguages),
          ]),
          SizedBox(height: 16),
          _buildMenuSection('Support', [
            _buildMenuItem(
              Icons.help_outline,
              'Help & Support',
              _showSupportDialog,
            ),
            _buildMenuItem(Icons.info_outline, 'About', _showAboutDialog),
            _buildMenuItem(
              Icons.privacy_tip_outlined,
              'Privacy Policy',
              _showPrivacyDialog,
            ),
          ]),
          SizedBox(height: 16),
          _buildMenuItem(
            Icons.logout,
            'Logout',
            _showLogout,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children:
                items.asMap().entries.map((entry) {
                  int index = entry.key;
                  Widget item = entry.value;
                  return Column(
                    children: [
                      item,
                      if (index < items.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: Colors.grey[200],
                          indent: 52,
                          endIndent: 16,
                        ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDestructive ? Colors.red.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(isDestructive ? 20 : 0),
        boxShadow:
            isDestructive
                ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.08),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
                : null,
      ),
      margin: isDestructive ? EdgeInsets.zero : null,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red[600] : Colors.green[600],
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red[600] : Colors.grey[800],
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey[400],
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDestructive ? 20 : 0),
        ),
      ),
    );
  }

  void _editProfile() {
    final nameController = TextEditingController(
      text: profileData?['name'] ?? '',
    );
    final locationController = TextEditingController(
      text: profileData?['location'] ?? '',
    );
    final phoneController = TextEditingController(
      text: profileData?['phone'] ?? '',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Save'),
                onPressed: () async {
                  Navigator.pop(context);
                  final updated = await updateProfile({
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                    'phone': phoneController.text.trim(),
                  });
                  if (updated) {
                    _showSnackBar('Profile updated successfully!');
                  } else {
                    _showSnackBar('Failed to update profile');
                  }
                },
              ),
            ],
          ),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔴 ALERT FOR USER
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange[800],
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "This feature is coming soon.",
                                style: TextStyle(
                                  color: Colors.orange[900],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Push Notifications'),
                        subtitle: Text(
                          'Receive weather alerts and crop advisories',
                        ),
                        value: _notificationsEnabled,
                        activeColor: Colors.green[600],
                        onChanged: (value) async {
                          setState(() => _notificationsEnabled = value);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('notifications_enabled', value);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Done'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showLanguages() {
    final languages = ['English', 'Hindi', 'Marathi', 'Gujarati', 'Tamil'];
    final selectedLanguage = profileData?['language'] ?? 'English';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Select Language',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔴 ALERT FOR USER
                Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.translate, color: Colors.blue[800], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "App text will remain in English. Translation is under development.",
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...languages
                    .map(
                      (language) => RadioListTile<String>(
                        title: Text(language),
                        value: language,
                        groupValue: selectedLanguage,
                        activeColor: Colors.green[600],
                        onChanged: (value) async {
                          Navigator.pop(context);
                          await updateProfile({'language': value});
                          _showSnackBar('Language preference saved: $value');
                        },
                      ),
                    )
                    .toList(),
              ],
            ),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  void _showLogout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Logout'),
                onPressed: () {
                  Navigator.pop(context);
                  _performLogout();
                },
              ),
            ],
          ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Help & Support'),
            content: Text(
              'For any help, feel free to contact the developer:\n\n'
              '📧 Email: rahulsharma.hps@gmail.com\n'
              '📞 Phone: +91-6396165371',
            ),
            actions: [
              TextButton(
                child: Text('Close'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('About AgriHive'),
            content: Text(
              'AgriHive is an AI-powered farming assistant developed as a hobby project.\n\n'
              '👨‍💻 Developer: Rahul Sharma\n'
              '🌱 Goal: To support farmers with disease detection, crop advisory, and management tools.\n\n',
            ),
            actions: [
              TextButton(
                child: Text('Close'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Privacy Policy'),
            content: Text(
              'There is no formal privacy policy. Just don’t misuse the app 😄',
            ),
            actions: [
              TextButton(
                child: Text('Got it'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }
}
