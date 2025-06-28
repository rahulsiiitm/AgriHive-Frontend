import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  _CompleteProfileScreenState createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _selectedLanguage = 'English';

  final List<String> _languages = ['English', 'Hindi', 'Marathi', 'Gujarati', 'Tamil'];
  bool _isSaving = false;

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showSnackBar('User not logged in');
      return;
    }

    final profileData = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'location': _locationController.text.trim(),
      'language': _selectedLanguage,
    };

    final response = await http.post(
      Uri.parse('http://agrihive-server91.onrender.com/save_farmer_profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, ...profileData}),
    );

    setState(() => _isSaving = false);

    if (response.statusCode == 200) {
      _showSnackBar('Profile saved successfully!');
      Navigator.pushReplacementNamed(context, '/home'); // or your main screen
    } else if (response.statusCode == 409) {
      _showSnackBar('Profile already exists. Please login again.');
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showSnackBar('Failed to save profile. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Your Profile'),
        backgroundColor: Colors.green[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Please fill the information below to continue.',
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Name cannot be empty' : null,
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Phone cannot be empty' : null,
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Location cannot be empty' : null,
              ),
              SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: InputDecoration(
                  labelText: 'Preferred Language',
                  border: OutlineInputBorder(),
                ),
                items: _languages
                    .map((lang) => DropdownMenuItem(
                          value: lang,
                          child: Text(lang),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLanguage = value;
                    });
                  }
                },
              ),
              SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Save Profile', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
