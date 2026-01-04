
# AgriHive – AI-Powered Farming Assistant

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Framework-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Firebase-Backend-orange?logo=firebase" />
  <img src="https://img.shields.io/badge/Dart-Language-blue?logo=dart" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>

<p align="center">
  <img src="assets/images/images_readme/Banner.png" width="85%" />
</p>

AgriHive is a **startup-oriented, AI-powered farming assistant** built with Flutter, focused on solving real-world agricultural challenges using technology that is simple, fast, and farmer-friendly.

---

## 🌍 The Problem

Modern farmers face multiple challenges:

- 🌦 Unpredictable weather patterns  
-  Crop diseases detected too late  
-  Lack of personalized, timely guidance  
-  Farming tools that are complex and not mobile-first  

Most solutions are either **too technical**, **not localized**, or **not designed for farmers**.

---

## 💡 The Solution – AgriHive

AgriHive brings **AI + mobile-first design** together to support farmers at every stage of cultivation.

| Feature Area | How AgriHive Helps |
|-------------|-------------------|
|  Crop Management | Simple crop tracking with lifecycle awareness |
|  AI Assistance | Disease detection & smart recommendations |
|  Weather Insights | Location-based, actionable daily insights |
|  Smart Chat | Conversational help in a familiar chat UI |
|  Personalization | Farmer profile & multilingual-ready UI |

---

##  Impact & Vision

- 🚜 Empowers small & marginal farmers with technology  
- 📊 Improves crop health through early disease awareness  
- ⏱ Saves time with smart, contextual suggestions  
- 🌱 Encourages data-driven, sustainable farming practices  

**Vision:**  
To become a unified digital farming companion that scales from crop advisory to livestock and supply-chain intelligence.

---

## Key Features

###  Plant Disease Detection (UI Flow)
- Upload images via camera or gallery  
- View predictions & treatment suggestions  
- Smooth preview → result experience  

###  Smart Chat Interface
- Clean, distraction-free chat UI  
- Chat history with sidebar navigation  
- Optimized for long conversations  

###  Weather-Based Insights
- Auto location detection  
- Daily farming recommendations  
- Minimal, readable weather cards  

###  Crop Management
- Add / update / remove crops  
- Track crop lifecycle  
- Offline-friendly UI  

###  User Profile
- Farmer profile setup  
- Location-based personalization  
- Multi-language ready UI  

---

##  Tech Stack (Frontend)

| Category | Tools |
|-------|------|
| Framework | Flutter |
| Language | Dart |
| Backend Services | Firebase Auth, Firestore |

###  Major Packages
`dash_chat_2` · `firebase_auth` · `cloud_firestore` · `image_picker` ·  
`shared_preferences` · `connectivity_plus` · `geolocator` · `http`

---

## 📁 Project Structure

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

## 📸 App Screenshots

<p align="center">
  <img src="assets/images/images_readme/home.jpeg" width="22%" />
  <img src="assets/images/images_readme/chat.jpeg" width="22%" />
  <img src="assets/images/images_readme/manage.jpeg" width="22%" />
  <img src="assets/images/images_readme/profile.jpeg" width="22%" />
</p>

---

##  Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Android Studio / VS Code
- Firebase Project

### Run Locally
```bash
git clone https://github.com/rahulsiiitm/agrihive.git
cd agrihive
flutter pub get
flutter run
```

---

##  Contributing

1. Fork the repository  
2. Create a feature branch  
3. Commit your changes  
4. Open a pull request  

---

##  License
MIT License

---

###  Developer
**Rahul Sharma**  
📧 rahulsharma.hps@gmail.com <br>
🌐 https://rahul.aishtrex.com/

> *AgriHive is a learning-driven project aimed at building scalable, impactful technology for agriculture.*
