import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:my_app/screens/login_screen.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _notificationsEnabled = true;
  String userId = 'user1';
  Map<String, dynamic>? profileData;
  final ImagePicker _picker = ImagePicker();
  final String apiBaseUrl = 'http://agrihive-server91.onrender.com';
  
  // Cache variables
  static Map<String, dynamic>? _cachedProfileData;
  static DateTime? _lastLoadTime;
  static const Duration _cacheValidDuration = Duration(minutes: 30);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileFromCache();
  }

  void _loadProfileFromCache() {
    // Check if we have valid cached data
    if (_cachedProfileData != null && 
        _lastLoadTime != null && 
        DateTime.now().difference(_lastLoadTime!) < _cacheValidDuration) {
      setState(() {
        profileData = _cachedProfileData;
      });
    } else {
      // Load from server only if cache is invalid or empty
      _loadProfile();
    }
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/get_farmer_profile?userId=$userId'));
      if (response.statusCode == 200) {
        final newProfileData = json.decode(response.body)['profile'];
        setState(() {
          profileData = newProfileData;
          _cachedProfileData = newProfileData;
          _lastLoadTime = DateTime.now();
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
      final response = await http.post(
        Uri.parse('$apiBaseUrl/update_farmer_profile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'updates': updates}),
      );
      
      if (response.statusCode == 200) {
        // Update cache immediately
        setState(() {
          profileData = {...profileData!, ...updates};
          _cachedProfileData = profileData;
          _lastLoadTime = DateTime.now();
        });
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> uploadPhoto(File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/upload_profile_photo'));
      request.fields['userId'] = userId;
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      ));
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: profileData == null
          ? Center(child: CircularProgressIndicator(color: Colors.green[600]))
          : RefreshIndicator(
              onRefresh: () => _loadProfile(forceRefresh: true),
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        SizedBox(height: 30),
                        _buildMenuItems(),
                        SizedBox(height: 40),
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
      expandedHeight: 240,
      floating: false,
      pinned: true,
      backgroundColor: Colors.grey[100],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            image: DecorationImage(
              image: AssetImage('assets/images/rice.jpg'), // Add your background image here
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
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 60),
                  _buildProfileAvatar(),
                  SizedBox(height: 16),
                  Text(
                    profileData!['name'] ?? 'Name',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, 
                           color: Colors.white.withOpacity(0.9), size: 15),
                      SizedBox(width: 4),
                      Text(
                        profileData!['location'] ?? 'Location',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
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
            color: Colors.white.withOpacity(0.3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 45,
            backgroundColor: Colors.white,
            backgroundImage: profileData!['profilePhoto'] != null
                ? NetworkImage(profileData!['profilePhoto'])
                : null,
            child: profileData!['profilePhoto'] == null
                ? Icon(Icons.person_outline, size: 50, color: Colors.green[600])
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _editPhoto,
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
                size: 16,
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
          _buildMenuSection('Profile', [
            _buildMenuItem(Icons.edit_outlined, 'Edit Profile', _editProfile),
            _buildMenuItem(Icons.notifications_outlined, 'Notifications', _showNotifications),
            _buildMenuItem(Icons.language_outlined, 'Language', _showLanguages),
          ]),
          SizedBox(height: 20),
          _buildMenuSection('Support', [
            _buildMenuItem(Icons.help_outline, 'Help & Support', () {}),
            _buildMenuItem(Icons.info_outline, 'About', () {}),
          ]),
          SizedBox(height: 20),
          _buildMenuItem(Icons.logout, 'Logout', _showLogout, isDestructive: true),
          SizedBox(height: 20),
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
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDestructive ? Colors.red.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(isDestructive ? 16 : 0),
        boxShadow: isDestructive ? [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ] : null,
      ),
      margin: isDestructive ? EdgeInsets.zero : null,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDestructive 
                ? Colors.red.withOpacity(0.1) 
                : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red[600] : Colors.green[600],
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red[600] : Colors.grey[800],
            fontSize: 16,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDestructive ? 16 : 0),
        ),
      ),
    );
  }

  void _editProfile() {
    final nameController = TextEditingController(text: profileData?['name'] ?? '');
    final locationController = TextEditingController(text: profileData?['location'] ?? '');
    final phoneController = TextEditingController(text: profileData?['phone'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
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

  void _editPhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final uploaded = await uploadPhoto(File(pickedFile.path));
      if (uploaded) {
        _loadProfile(forceRefresh: true);
        _showSnackBar('Profile photo updated!');
      } else {
        _showSnackBar('Photo upload failed');
      }
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
          content: SwitchListTile(
            title: Text('Push Notifications'),
            subtitle: Text('Receive weather alerts and crop advisories'),
            value: _notificationsEnabled,
            activeColor: Colors.green[600],
            onChanged: (value) => setState(() => _notificationsEnabled = value),
          ),
          actions: [
            TextButton(
              child: Text('Done', style: TextStyle(color: Colors.green[600])),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Select Language', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((language) => RadioListTile<String>(
            title: Text(language),
            value: language,
            groupValue: selectedLanguage,
            activeColor: Colors.green[600],
            onChanged: (value) async {
              Navigator.pop(context);
              await updateProfile({'language': value});
              _showSnackBar('Language changed to $value');
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Logout'),
            onPressed: () {
              Navigator.pop(context);
              // Clear cache on logout
              _cachedProfileData = null;
              _lastLoadTime = null;
              // Navigate to login page and remove all previous routes
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}