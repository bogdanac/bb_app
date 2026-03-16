# BBetter Web Deployment Guide

Your app now supports responsive desktop/web layouts with a side navigation bar for screens wider than 1024px!

## What's New

### Responsive Layout
- **Mobile (< 1024px)**: Bottom navigation bar (original design)
- **Desktop (>= 1024px)**: Side navigation bar on the left
- **Automatic sync**: All changes sync through Firebase between mobile and web

### Files Created/Modified
1. `lib/utils/responsive_layout.dart` - Responsive utilities and breakpoint detection
2. `lib/widgets/side_navigation.dart` - Side navigation component for desktop
3. `lib/main.dart` - Updated to support responsive navigation
4. `lib/home.dart` - Added max-width constraint for better desktop display
5. `web/index.html` - Enhanced with proper meta tags and loading screen
6. `web/manifest.json` - Updated with app branding
7. `firebase.json` - Firebase Hosting configuration
8. `.firebaserc` - Firebase project configuration

## Deployment Steps

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Login to Firebase
```bash
firebase login
```

### 3. Initialize Firebase Project
Update `.firebaserc` with your actual Firebase project ID:
```json
{
  "projects": {
    "default": "your-actual-firebase-project-id"
  }
}
```

You can find your project ID in the Firebase Console at https://console.firebase.google.com/

### 4. Build for Web
```bash
flutter build web --release
```

For better performance with WebAssembly (recommended):
```bash
flutter build web --release --wasm
```

### 5. Deploy to Firebase Hosting
```bash
firebase deploy --only hosting
```

### 6. Access Your Web App
After deployment, Firebase will provide you with a hosting URL like:
- `https://your-project-id.web.app`
- `https://your-project-id.firebaseapp.com`

## Local Testing

### Option 1: Using Flutter
```bash
flutter run -d chrome
```

### Option 2: Using Firebase Emulator
```bash
firebase serve
```

### Option 3: Using Python HTTP Server
```bash
cd build/web
python -m http.server 8000
```
Then open http://localhost:8000

## Firebase Sync

Your app already uses Firebase Firestore and Firebase Auth, so all data automatically syncs between:
- Android app
- iOS app (if you build it)
- Web app

No additional configuration needed for sync!

## Features on Web

### Working Features
- All main screens (Home, Fasting, Cycle, Tasks, Routines)
- Firebase authentication
- Real-time data sync
- Responsive layout

### Platform-Specific Limitations
The following features are mobile-only and won't work on web:
- Local notifications (use web push notifications instead)
- Calendar integration
- File system access (Download folder)
- Android widgets
- Sound playback (may have browser limitations)
- Platform-specific permissions

## Customization

### Adjusting Breakpoints
Edit `lib/utils/responsive_layout.dart`:
```dart
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1024;
}
```

### Side Navigation Width
Edit `lib/widgets/side_navigation.dart`:
```dart
Container(
  width: 200, // Change this value
  ...
)
```

### Content Max Width
Edit `lib/home.dart` (and other screens):
```dart
ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 800), // Change this value
  ...
)
```

## Custom Domain

To use a custom domain:

1. Go to Firebase Console > Hosting
2. Click "Add custom domain"
3. Follow the instructions to verify ownership
4. Add the DNS records provided by Firebase

## Security Rules

Make sure your Firestore security rules are properly configured in the Firebase Console to prevent unauthorized access to user data.

## Continuous Deployment

For automatic deployments, you can use GitHub Actions:

1. Add Firebase token as GitHub secret:
```bash
firebase login:ci
```

2. Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy to Firebase Hosting
on:
  push:
    branches:
      - main

jobs:
  build_and_deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build web --release
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: your-project-id
```

## Troubleshooting

### Build Errors
- Run `flutter clean` then `flutter pub get`
- Make sure you're on the latest Flutter version: `flutter upgrade`

### Firebase Errors
- Verify your Firebase project is properly initialized
- Check that your `.firebaserc` has the correct project ID
- Make sure you're logged in: `firebase login`

### Layout Issues
- Test on different screen sizes using browser dev tools
- Adjust breakpoints in `responsive_layout.dart` if needed

## Performance Tips

1. Use `--wasm` flag for better performance
2. Enable compression on Firebase Hosting (automatic)
3. Optimize images before adding to assets
4. Use lazy loading for heavy widgets

## Next Steps

1. Test the web app on different browsers (Chrome, Firefox, Safari, Edge)
2. Test on different devices (desktop, tablet, mobile)
3. Configure Firebase App Check for added security
4. Set up web push notifications if needed
5. Add Google Analytics for web tracking
6. Consider PWA features (offline support, install prompt)

Enjoy your multi-platform app!
