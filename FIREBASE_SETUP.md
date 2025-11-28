# Firebase Setup Guide

## Prerequisites

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

## Setup Steps

### 1. Configure Firebase for Flutter

Run the following command in your project root:
```bash
flutterfire configure
```

This will:
- Detect your Firebase projects
- Generate `lib/firebase_options.dart` with proper configuration
- Configure Android and iOS projects

### 2. Enable Google Sign-In in Firebase Console

1. Go to Firebase Console → Authentication → Sign-in method
2. Enable "Google" as a sign-in provider
3. Add your app's package name: `com.codeink.stsl.subscriptions`
4. Save the configuration

### 3. Android Configuration

1. **Get SHA-1 Fingerprint:**
   ```bash
   keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore
   ```
   (Password is usually `android`)

2. **Add SHA-1 to Firebase:**
   - Go to Firebase Console → Project Settings → Your Android App
   - Add the SHA-1 fingerprint

3. **Update `android/app/build.gradle.kts`:**
   - Ensure `minSdk` is at least 21
   - Ensure Google Services plugin is applied

### 4. iOS Configuration

1. **Download `GoogleService-Info.plist`:**
   - From Firebase Console → Project Settings → Your iOS App
   - Place it in `ios/Runner/`

2. **Update `ios/Runner/Info.plist`:**
   - Add the reversed client ID from `GoogleService-Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>YOUR_REVERSED_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

### 5. Update App Config

After running `flutterfire configure`, update `lib/core/config/app_config.dart`:

```dart
static const String firebaseApiKey = 'YOUR_API_KEY'; // From firebase_options.dart
static const String firebaseAppId = 'YOUR_APP_ID';
static const String firebaseProjectId = 'YOUR_PROJECT_ID';
static const String firebaseMessagingSenderId = 'YOUR_SENDER_ID';
```

Or better yet, read from `firebase_options.dart` directly.

### 6. Firestore Security Rules

Set up security rules in Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /subscriptions/{subscriptionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

## Testing

Once configured:
1. Run `flutter run`
2. Navigate to Settings → Cloud Sync
3. Tap "Sign in with Google"
4. Complete the OAuth flow
5. Your subscriptions will sync to Firestore

## Troubleshooting

### "GoogleSignIn doesn't have an unnamed constructor"
- Ensure Firebase is initialized in `main.dart`
- Run `flutterfire configure` to generate `firebase_options.dart`

### "Sign-in failed"
- Check SHA-1 fingerprint is added to Firebase (Android)
- Verify OAuth client ID is configured (iOS)
- Ensure Google Sign-In is enabled in Firebase Console

### "Firebase not configured"
- Update `app_config.dart` with Firebase credentials
- Or modify `CloudSyncService` to read from `firebase_options.dart` directly

