import 'package:flutter/material.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFF5),
      body: Column(
        children: [
          _buildTopBanner(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserInfoCard(),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Profile Details"),
                  _buildInfoTile("📍 Region", "Imphal, Manipur"),
                  _buildInfoTile("🌿 Crops", "Paddy, Tomato, Maize, Wheat"),
                  _buildInfoTile("⭐ Plan", "Premium"),
                  _buildInfoTile("🔔 Alerts", "Disease, Fertilizer, Weather"),
                  _buildInfoTile("🌐 Language", "Hindi"),
                  const SizedBox(height: 25),
                  _buildSectionTitle("Preferences"),
                  _buildToggleTile("Receive Alerts", true),
                  _buildToggleTile("Show Weather Tips", true),
                  _buildToggleTile("Auto Crop Suggestions", false),
                  const SizedBox(height: 25),
                  _buildSectionTitle("Quick Actions"),
                  _buildActionButtons(),
                  const SizedBox(height: 25),
                  _buildSectionTitle("Progress"),
                  _buildProgressCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBanner(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/image1.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          left: 0,
          right: 0,
          child: Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: const CircleAvatar(
                radius: 46,
                backgroundImage: AssetImage('assets/images/app_icon.png'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard() {
    return Column(
      children: const [
        SizedBox(height: 50),
        Text(
          "Rahul Sharma",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        SizedBox(height: 4),
        Text(
          "rahul.farmer@gmail.com",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF388E3C),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(
            child: Text(
              subtitle,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile(String title, bool enabled) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Switch(
            value: enabled,
            onChanged: (_) {},
            activeColor: const Color(0xFF66BB6A),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF66BB6A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text("Edit Profile"),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD84315),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text("Logout"),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🧑‍🌾 Profile Completion", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: 0.75,
            backgroundColor: Colors.grey[200],
            color: const Color(0xFF66BB6A),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          const Text("75% complete", style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}