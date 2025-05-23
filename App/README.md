# WellSync - IoT & AI Based Digital Wellness Assistant

---

# WellSync Mobile Application (Flutter Base)

---

## Project Overview

The WellSync Flutter application serves as the user interface for the IoT-based Digital Wellness Assistant system, providing real-time emotional state monitoring and personalized interventions. This cross-platform mobile app integrates with ESP32 CAM hardware through Firebase cloud services, offering:

- Continuous biometric data visualization
- AI-driven wellness recommendations
- Historical mood pattern analysis
- Secure device configuration management

---

## Key Features

### Core Functionalities

- **Real-time Emotion Monitoring**: Processes IoT device data streams for instant stress detection
- **Context-Aware Interventions**: Delivers personalized coping strategies using ML models
- **Multi-Modal Interaction**: Supports text/voice input for wellness journaling
- **Device Management**: Secure BLE pairing and OTA firmware updates

### Technical Capabilities

- **Firebase Integration**: Real-time database synchronization and user authentication
- **Modular Architecture**: Clean separation of UI components and business logic
- **Adaptive UI**: Responsive layouts for mobile/tablet devices
- **Privacy-First Design**: Local data processing with optional cloud sync

---

## Installation

### Development Requirements

- Flutter SDK 3.27.1+
- Dart 3.1.0+
- Android Studio/Xcode for platform-specific builds

```bash
# Clone repository
git clone https://github.com/isharaimagines/IoT-App.git
cd IoT-App/App

# Install dependencies
flutter pub get

# Run development build
flutter run
```

---

## Configuration

### Firebase Setup

1. Create Firebase project at https://console.firebase.google.com
2. Add Android/iOS apps and download configuration files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
3. Enable authentication providers:
   - Google Sign-In

### Environment Variables

Create `.env` file in project root:

```env
API_KEY=ai_model_api_key
API_MODEL=ai_model_name
```

Google firebase configuration for Mobile App

```
./android/app/google-services.json
```

---

## Application Architecture

### Component Structure

```plaintext
lib/
├── components/
│   ├── chat_message.dart        # Chat bubble with sentiment visualization
│   ├── device_config_page.dart  # IoT pairing interface components
│   ├── show_emotion_dialog.dart # Real-time emotion feedback widgets
│   └── sign_in_page.dart        # Google sign In widgets
|
├── pages/
│   ├── chat_page.dart     # AI Assistant chat bot
│   ├── home_page.dart     # Today Insight analysis
│   ├── mood_page.dart     # Historical emotion analysis
│   └── profile_page.dart  # Account management UI
|
|
└── main.dart                # Application entry point
```

---

## Device Integration

### WiFi Configure Process

1. Enable WiFi on mobile device
2. Navigate to **Today → Connect Device**
3. Select WellSync device from discovered list
4. Config with IoT device

---

## Troubleshooting

| Symptom                     | Resolution                                                    |
| --------------------------- | ------------------------------------------------------------- |
| **Missing Firebase Config** | Verify google-services.json file location                     |
| **BLE Connection Drops**    | Check device proximity (<10m recommended)                     |
| **UI Rendering Issues**     | Execute `flutter clean && ./gradlew clean && flutter pub get` |

---

## Documentation Links

- [WellSync IoT Device Readme](../Device/README.md)
- [Flutter Firebase Integration Guide](https://firebase.flutter.dev)
- [ESP32 CAM Documentation](https://espressif.com)

**License**: MIT  
**Maintainer**: Goigoda Siriwardhana  
**Contact**: [10898919@students.plymouth.ac.uk]
