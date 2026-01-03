# AgriHive – AI-Powered Farming Assistant

![AgriHive Banner](assets/images/images_readme/Banner.png)

AgriHive is a Flutter-based mobile application that helps farmers manage crops, detect plant diseases, and get smart farming insights through an intuitive and modern user interface.

---

## Overview

AgriHive focuses on delivering a **simple, fast, and farmer-friendly mobile experience**.  
The app brings together crop management, AI-assisted insights, weather awareness, and conversational help — all wrapped in a clean Flutter UI.

---

## Key Features

### 🌱 Plant Disease Detection (UI Flow)
- Upload plant images from the gallery or camera
- View disease predictions and treatment suggestions
- Smooth image preview and result screens

### 💬 Smart Chat Interface
- Clean conversational UI for farming queries
- Chat history with sidebar navigation
- Optimized for long conversations

### ☁️ Weather-Based Insights
- Location-aware weather cards
- Actionable daily farming suggestions
- Minimal and readable data presentation

### 🌾 Crop Management
- Add, update, and remove crops easily
- Track planting dates and crop stages
- Offline-friendly experience

### 👤 User Profile
- Farmer profile setup
- Multi-language ready UI
- Location-based personalization

---

## Tech Stack (Frontend)

- **Framework**: Flutter  
- **Language**: Dart  

### Major Packages Used
- dash_chat_2
- firebase_auth
- cloud_firestore
- image_picker
- shared_preferences
- connectivity_plus
- geolocator
- http

---

## App Structure (Frontend)

```
lib/
├── main.dart
├── home.dart
├── chatpage.dart
├── management.dart
├── profile_page.dart
├── get_started.dart
├── screens/
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   └── save_profile.dart
├── services/
│   └── auth_service.dart
└── weather/
    ├── weather_card.dart
    └── weather_service.dart
```

---

## Screenshots

| Home | Chat |
|------|------|
| ![](assets/images/images_readme/home.jpeg) | ![](assets/images/images_readme/chat.jpeg) |

| Crop Management | Profile |
|----------------|---------|
| ![](assets/images/images_readme/manage.jpeg) | ![](assets/images/images_readme/profile.jpeg) |

---

## Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Android Studio / VS Code
- Firebase project

### Run Locally
```bash
git clone https://github.com/rahulsiiitm/agrihive.git
cd agrihive
flutter pub get
flutter run
```

---

## Usage Flow

1. Sign up or log in  
2. Complete your farmer profile  
3. Add crops  
4. View daily suggestions  
5. Chat or upload plant images  

---

## Contributing

Contributions are welcome:
1. Fork the repository
2. Create a new branch
3. Commit changes
4. Open a pull request

---

## License

MIT License

---

**Developer**: Rahul Sharma  
📧 rahulsharma.hps@gmail.com  

> AgriHive is a learning-driven project focused on building meaningful technology for agriculture.
