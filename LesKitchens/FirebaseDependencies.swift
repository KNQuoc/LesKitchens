import Foundation

/*
 To set up Firebase in your project, follow these steps:

 1. Install the Firebase iOS SDK using Swift Package Manager:
    - In Xcode, go to File > Add Packages...
    - Enter the Firebase SDK URL: https://github.com/firebase/firebase-ios-sdk
    - Select the following products:
        - FirebaseAuth
        - FirebaseFirestore
        - FirebaseAnalytics (optional but recommended)

 2. Create a Firebase project and register your app:
    - Go to https://console.firebase.google.com/
    - Create a new project or select an existing one
    - Add an iOS app to your project
    - Download the GoogleService-Info.plist file
    - Add this file to your Xcode project (make sure to check "Copy items if needed")

 3. Initialize Firebase in your app's startup code:
    - This is already done in LesKitchensApp.swift

 4. Make sure you have appropriate security rules in your Firestore database:
    - Example rules:

    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        match /users/{userId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;

          match /data/{document=**} {
            allow read, write: if request.auth != null && request.auth.uid == userId;
          }
        }
      }
    }
 */
