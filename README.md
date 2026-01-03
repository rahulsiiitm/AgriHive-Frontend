# AgriHive - Agricultural Advisory System

![just a banner](<assets/images/images_readme/Banner.png>)

A comprehensive mobile application designed to assist farmers with AI-powered plant disease detection, crop management, weather-based farming suggestions, and an intelligent agricultural chatbot.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration](#configuration)
- [API Documentation](#api-documentation)
- [Screenshots](#screenshots)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## Overview

AgriHive is an intelligent farming assistant that leverages artificial intelligence and real-time weather data to provide farmers with actionable insights for crop management. The application combines computer vision for plant disease detection, natural language processing for conversational assistance, and weather analytics for personalized farming recommendations.

## Features

### Core Functionality

- **AI-Powered Plant Disease Detection**
  - Upload plant images for instant disease analysis
  - Powered by custom-trained machine learning models
  - Detailed treatment recommendations via Gemini AI

- **Intelligent Agricultural Chatbot**
  - Natural conversation interface for farming queries
  - Context-aware responses based on crop history
  - Multi-turn conversation support with history

- **Weather-Based Suggestions**
  - Real-time weather data integration
  - Personalized farming advice based on local conditions
  - Daily actionable recommendations tailored to user's crops

- **Crop Management System**
  - Track multiple crops with planting dates and areas
  - Monitor crop age and growth stages
  - CRUD operations with offline caching support

- **User Profile Management**
  - Customizable farmer profiles
  - Multi-language support
  - Location-based services

### Technical Features

- **Offline-First Architecture**
  - SharedPreferences-based local caching
  - Automatic cache invalidation after 30 minutes
  - Seamless online/offline transitions

- **Firebase Integration**
  - Authentication via Firebase Auth
  - Cloud Firestore for data persistence
  - Real-time synchronization

- **Optimized Performance**
  - Lazy loading of chat history
  - Memory-efficient image processing
  - Minimal token usage per user preference

## Technology Stack

### Frontend (Flutter)

- **Framework**: Flutter
- **Language**: Dart
- **Key Packages**:
  - `dash_chat_2` - Chat interface
  - `firebase_auth` - Authentication
  - `cloud_firestore` - Database
  - `http` - API communication
  - `shared_preferences` - Local storage
  - `image_picker` - Image selection
  - `connectivity_plus` - Network status
  - `geolocator` - Location services

### Backend (Python/Flask)

- **Framework**: Flask
- **Language**: Python
- **Key Libraries**:
  - `google-generativeai` - Gemini AI integration
  - `firebase-admin` - Firebase Admin SDK
  - `requests` - HTTP client
  - `python-dotenv` - Environment management
  - `flask-cors` - Cross-origin support

### APIs and Services

- **Google Gemini AI** - Natural language processing and image analysis
- **OpenWeather API** - Real-time weather data
- **Hugging Face** - Custom plant disease detection model
- **Firebase Services** - Authentication, Firestore, Storage

## Architecture

### Application Structure

```
lib/
├── main.dart                      # Application entry point
├── chatpage.dart                  # Chat interface with AI
├── home.dart                      # Home dashboard with suggestions
├── management.dart                # Crop management interface
├── profile_page.dart              # User profile management
├── chat_history_sidebar.dart      # Chat history UI component
├── get_started.dart               # Onboarding screen
├── firebase_options.dart          # Firebase configuration
├── screens/
│   ├── login_screen.dart          # Authentication UI
│   ├── signup_screen.dart         # User registration
│   └── save_profile.dart          # Profile completion
├── services/
│   └── auth_service.dart          # Authentication logic
└── weather/
    ├── weather_card.dart          # Weather display component
    └── weather_service.dart       # Weather data management

functions/
└── app.py                         # Flask backend server
```

### Data Flow

1. **User Authentication**: Firebase Auth handles user login/signup
2. **Data Storage**: User-specific data stored in Firestore collections
3. **API Communication**: Flutter app communicates with Flask backend via REST API
4. **AI Processing**: Backend processes requests using Gemini AI and custom ML models
5. **Weather Integration**: Real-time weather data fetched from OpenWeather API
6. **Local Caching**: Critical data cached locally for offline access

## Installation

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Python 3.8 or higher
- Firebase project with Firestore and Authentication enabled
- API keys for Google Gemini, OpenWeather, and Hugging Face

### Frontend Setup

```bash
# Clone the repository
git clone https://github.com/rahulsiiitm/agrihive.git
cd agrihive

# Install Flutter dependencies
flutter pub get

# Run the application
flutter run
```

## Configuration

### Firebase Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication (Email/Password)
3. Create a Firestore database
4. Download the service account key JSON
5. Update `lib/firebase_options.dart` with your Firebase configuration

## API Documentation

### Chat Endpoint

**POST** `/chat`

Send a message to the agricultural chatbot.

**Request Body**:
```json
{
  "message": "How do I treat wheat rust?",
  "user_id": "firebase_user_id",
  "chat_id": "optional_chat_id"
}
```

**Response**:
```json
{
  "success": true,
  "response": "AI-generated response",
  "chat_id": "chat_session_id",
  "is_new_chat": false
}
```

### Image Analysis Endpoint

**POST** `/analyze_image`

Analyze plant images for disease detection.

**Request**: Multipart form data
- `image`: Plant image file
- `user_id`: Firebase user ID
- `chat_id`: Optional chat session ID

**Response**:
```json
{
  "success": true,
  "predicted_label": "Wheat Rust",
  "gemini_explanation": "Detailed explanation and treatment",
  "chat_id": "chat_session_id"
}
```

### Weather Endpoint

**GET** `/weather?lat=27.1767&lon=78.0081`

Retrieve current weather and forecast data.

**Response**:
```json
{
  "success": true,
  "weather": {
    "current": {
      "temperature": 28.5,
      "humidity": 65,
      "description": "clear sky"
    },
    "forecast": []
  }
}
```

### Crop Management Endpoints

- **POST** `/addCrop` - Add new crops
- **GET** `/getCrops?userId=user_id` - Retrieve user's crops
- **PUT** `/updateCrop` - Update crop information
- **DELETE** `/deleteCrop` - Remove a crop

### Suggestions Endpoint

**GET** `/getSuggestions?userId=user_id&lat=27.1767&lon=78.0081`

Get personalized farming suggestions based on crops and weather.

**Response**:
```json
{
  "success": true,
  "suggestions": {
    "first": {
      "text": "Water your wheat early morning",
      "category": "irrigation",
      "crop": "wheat",
      "priority": "high"
    }
  }
}
```

## Screenshots

<table>
  <tr>
    <td width="50%" align="center">
      <strong>Home Screen</strong><br/>
      <img src="assets/images/images_readme/home.jpeg" width="300"/>
    </td>
    <td width="50%" align="center">
      <strong>Chat Interface</strong><br/>
      <img src="assets/images/images_readme/chat.jpeg" width="300"/>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <strong>Crop Management</strong><br/>
      <img src="assets/images/images_readme/manage.jpeg" width="300"/>
    </td>
    <td width="50%" align="center">
      <strong>Profile Management</strong><br/>
      <img src="assets/images/images_readme/profile.jpeg" width="300"/>
    </td>
  </tr>
</table>

## Usage

### Getting Started

1. **Sign Up/Login**: Create an account or log in with existing credentials
2. **Add Crops**: Navigate to the Plantation Management page and add your crops
3. **View Suggestions**: Check the home screen for daily farming recommendations
4. **Chat Assistant**: Use the chat feature to ask farming questions
5. **Analyze Plants**: Upload plant images for disease detection

### Best Practices

- Keep crop information updated for accurate suggestions
- Enable location services for weather-based recommendations
- Upload clear plant images for better disease detection
- Regularly check daily suggestions on the home screen

## Contributing

We welcome contributions to AgriHive! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -m 'Add YourFeature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Open a Pull Request

### Code Style

- Follow Flutter's official style guide
- Use meaningful variable names
- Add comments for complex logic
- Ensure all tests pass before submitting

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Developer**: Rahul Sharma  
**Contact**: rahulsharma.hps@gmail.com  
**Phone**: +91-6396165371

**Note**: This is a hobby project aimed at supporting farmers with AI-powered agricultural assistance. For production use, additional security measures and scalability improvements are recommended.