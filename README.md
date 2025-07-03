# Kinette

This is the Swift-Native version of Kinette, a kitchen assistant app that I made

## 🍳 Features

### Core Functionality
- **Smart Shopping Lists** - Create and manage shopping lists with quantity tracking
- **Kitchen Inventory Management** - Track what's in your kitchen with expiration dates
- **Group Sharing** - Share kitchen inventories with family members or roommates
- **Voice Assistant** - Add items to your shopping list using voice commands
- **Location-Based Notifications** - Get notified when you're near grocery stores
- **Google Places Integration** - Find nearby grocery stores automatically

### User Experience
- **Dark Mode Support** - Seamless light and dark theme compatibility
- **Home Screen Widget** - Quick access to your shopping list and nearby stores
- **Cross-Device Sync** - Cloud-based storage with Firebase
- **Authentication** - Secure login with email/password or Google Sign-In

## 🏗️ Technical Architecture

### Built With
- **SwiftUI** - Modern iOS UI framework
- **Firebase** - Authentication, Firestore database, and real-time sync
- **Google Places API** - Location services and store discovery
- **Speech Recognition** - Voice command processing
- **Core Location** - GPS tracking and geofencing
- **WidgetKit** - Home screen widget functionality

### Architecture Pattern
- **MVVM (Model-View-ViewModel)** - Clean separation of concerns
- **Combine Framework** - Reactive programming for data flow
- **Service Layer** - Dedicated services for location, voice, and API interactions

## 🚀 Getting Started

### Prerequisites
- Xcode 16.3 or later
- iOS 17.6+ deployment target
- Apple Developer account (for device testing)
- Google Cloud Platform account (for Places API)
- Firebase project setup

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/LesKitchens.git
   cd LesKitchens
   ```

2. **Set up Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Authentication, Firestore Database, and Realtime Database
   - Download the `GoogleService-Info.plist` file
   - Replace the existing plist file in the project

3. **Configure Google Places API**
   - Enable the Places API in your Google Cloud Console
   - Create an API key and restrict it to iOS apps
   - Update the `GooglePlacesAPIKey` in `Info.plist` with your API key

4. **Configure Google Sign-In**
   - Copy your Firebase project's client ID
   - Update the `GIDClientID` in `Info.plist`
   - Ensure the URL scheme matches your client ID

5. **Open the project**
   ```bash
   open LesKitchens.xcodeproj
   ```

6. **Update Bundle Identifier**
   - Change the bundle identifier to your own unique identifier
   - Update the App Group identifier in the entitlements files

7. **Build and Run**
   - Select your target device or simulator
   - Build and run the project (⌘+R)

### Required Permissions

The app requires the following permissions:
- **Location Services** - For nearby store notifications
- **Microphone** - For voice commands  
- **Speech Recognition** - For processing voice input
- **Notifications** - For location-based alerts

## 📁 Project Structure

```
LesKitchens/
├── LesKitchens/
│   ├── Views/
│   │   ├── Authentication/          # Login and registration views
│   │   ├── Profile/                # User profile management
│   │   └── VoiceAssistantView.swift # Voice command interface
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift      # Authentication logic
│   │   └── KitchenViewModel.swift   # Main app state management
│   ├── Services/
│   │   ├── GooglePlacesService.swift    # Places API integration
│   │   ├── LocationServices.swift       # GPS and geofencing
│   │   └── VoiceAssistantManager.swift  # Speech recognition
│   ├── Assets.xcassets/             # App icons and color themes
│   └── Supporting Files/
├── Widget/                          # Home screen widget
├── LesKitchensTests/               # Unit tests
└── LesKitchensUITests/             # UI tests
```

## 🔧 Configuration

### Environment Variables
Create or update the following in your `Info.plist`:

```xml
<key>GooglePlacesAPIKey</key>
<string>YOUR_GOOGLE_PLACES_API_KEY</string>

<key>GIDClientID</key>
<string>YOUR_GOOGLE_CLIENT_ID</string>
```

### Firebase Security Rules
Ensure your Firestore security rules allow authenticated users to read/write their own data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /groups/{groupId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.members;
    }
  }
}
```

## 🎯 Usage

### Getting Started
1. **Sign Up/Login** - Create an account or sign in with Google
2. **Grant Permissions** - Allow location and microphone access for full functionality
3. **Add Items** - Start building your shopping list manually or with voice commands
4. **Create Groups** - Invite family members to share kitchen inventories
5. **Enable Notifications** - Get alerts when you're near grocery stores

### Voice Commands
The voice assistant supports natural language commands like:
- "Add 2 pounds of ground beef"
- "Add milk to shopping list"
- "Buy three bottles of olive oil"
- "Get some bread"

### Widget Usage
- Long press on your home screen and add the LesKitchens widget
- View your shopping list and nearest grocery stores at a glance
- Tap to open the full app

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow SwiftUI best practices
- Maintain MVVM architecture
- Add unit tests for new features
- Update documentation as needed
- Ensure accessibility compliance

## 🐛 Known Issues

- Voice recognition may not work properly in noisy environments
- Location services require "Always" permission for background notifications
- Widget updates may be delayed based on iOS system limits

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Credits

- **Speech Recognition** - Apple's Speech framework
- **Location Services** - Apple's Core Location
- **Places Data** - Google Places API
- **Backend Services** - Firebase
- **Icons** - SF Symbols

## 📞 Support

For support, please:
1. Check the [Issues](https://github.com/yourusername/LesKitchens/issues) page
2. Create a new issue with detailed information
3. Contact the development team

## 🔮 Roadmap

- [ ] Recipe integration and meal planning
- [ ] Barcode scanning for inventory management
- [ ] Nutrition tracking and dietary preferences
- [ ] Smart shopping suggestions based on usage patterns
- [ ] Integration with grocery store apps
- [ ] Apple Watch companion app

---

Built with ❤️ using SwiftUI and Firebase 