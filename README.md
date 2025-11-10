# TRIminder - Digital Wellness Gamification App

TRIminder is a Flutter-based digital wellness application that automatically tracks screen time and rewards users with XP for spending LESS time on their devices. The app features social elements, rankings, and gamification to encourage healthy digital habits.

## Features

### Core Functionality
- **Automatic Screen Time Tracking**: 24/7 background monitoring without user intervention
- **Inverse Gamification**: Earn XP for LESS screen time (digital wellness approach)
- **Social Features**: Friend system, user tags, department and global rankings
- **Offline-First Architecture**: Local SQLite database with cloud sync via Supabase
- **Persistent Background Service**: Survives device restarts and app closures

### Technical Features
- **Smart Idle Detection**: Differentiates between active and passive screen time
- **Session Management**: 3-minute minimum recordable sessions with midnight rollover handling
- **Badge System**: Achievement system for digital wellness milestones
- **Cross-Platform**: Built with Flutter for Android (iOS support planned)

## System Requirements

### Minimum Requirements
- **Android 8.0 (API 26)** or higher
- **2GB RAM** minimum
- **100MB** available storage
- **Internet connection** for cloud sync (optional)

### Recommended
- **Android 10+** for optimal background service performance
- **4GB RAM** or more
- **500MB** available storage

## Installation

### Prerequisites
- Flutter SDK 3.9.0 or higher
- Android Studio or VS Code with Flutter extensions
- Android device or emulator (API 26+)

### Setup
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd TRIminder
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure environment variables:
   - Copy `.env.example` to `.env`
   - Add your Supabase URL and anonymous key

4. Run the app:
   ```bash
   flutter run
   ```

## Permissions

TRIminder requires the following permissions for optimal functionality:

### Required Permissions
- **Battery Optimization Bypass**: Critical for 24/7 background tracking (Android 6.0+)
- **Internet**: For cloud synchronization and authentication
- **Wake Lock**: Prevents device sleep during active tracking

### Optional Permissions
- **Notifications** (Android 13+): For foreground service notifications
- **Exact Alarm** (Android 12+): For reliable timer functionality (requires manual grant via Settings > Apps > Special app access > Alarms & reminders)
- **USAGE_STATS**: For enhanced screen state detection (optional, requires manual grant via Settings > Apps > Special app access > Usage access)

### Permission Justification
- **Battery Optimization**: Required to maintain background service for continuous screen time tracking
- **Internet**: Used for user authentication and data synchronization with Supabase backend
- **Wake Lock**: Ensures accurate session tracking without device sleep interference
- **Exact Alarm**: Ensures reliable timer functionality for session tracking on Android 12+
- **USAGE_STATS**: Optional permission for enhanced screen state detection (app works without it on most devices)

## Troubleshooting

### Background Service Issues

#### Common Problems
1. **Service stops after device sleep**
   - **Solution**: Disable battery optimization for TRIminder
   - **Steps**: Settings → Apps → TRIminder → Battery → "Allow background activity"

2. **Service doesn't start after reboot**
   - **Solution**: Enable auto-start permission (manufacturer-specific)
   - **Xiaomi**: Settings → Apps → Manage apps → TRIminder → Autostart
   - **Huawei**: Settings → Apps → Apps → TRIminder → Battery → "Allow background activity"

3. **Inaccurate screen time tracking**
   - **Solution**: Ensure all permissions are granted
   - **Check**: App settings → Permissions → All permissions enabled

#### Manufacturer-Specific Setup

**Xiaomi (MIUI)**
1. Settings → Apps → Manage apps → TRIminder
2. Battery saver → "No restrictions"
3. Autostart → Enable
4. Battery optimization → "Don't optimize"

**Huawei (EMUI)**
1. Settings → Apps → Apps → TRIminder
2. Battery → "Allow background activity"
3. App launch → Manual (disable restrictions)

**Samsung (One UI)**
1. Settings → Apps → TRIminder
2. Battery → "Allow background activity"
3. Device care → Battery → App power management → Unrestricted

**Oppo/Realme (ColorOS)**
1. Settings → Apps → App management → TRIminder
2. Battery → "Allow background activity"
3. Background app management → Allow TRIminder

### Data Sync Issues

#### Offline Mode
- TRIminder works offline with local SQLite database
- Data syncs automatically when internet connection is restored
- Manual sync available via pull-to-refresh in dashboard

#### Sync Problems
1. **Data not syncing**
   - Check internet connection
   - Verify Supabase configuration
   - Try manual sync from dashboard

2. **Duplicate entries**
   - App handles deduplication automatically
   - Contact support if issues persist

## Development

### Architecture
- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL)
- **Local Database**: SQLite (sqflite)
- **State Management**: Provider pattern
- **Background Services**: flutter_background_service

### Key Components
- `lib/services/persistent_tracker_service.dart`: Core background tracking
- `lib/services/supabase_service.dart`: Cloud authentication and sync
- `lib/services/database_service.dart`: Local data management
- `lib/utils/battery_optimization_helper.dart`: Manufacturer-specific optimizations
- `lib/utils/android_permission_helper.dart`: Android version-specific permission handling

### Android Version Compatibility
- **Android 8.0+ (API 26+)**: Full support with notification channels and background restrictions
- **Android 12+ (API 31+)**: Exact alarm permission support for reliable timers
- **Android 13+ (API 33+)**: Runtime notification permission support
- **Android 14+ (API 34+)**: Foreground service type declarations
- **Android 15+ (API 35+)**: Data extraction rules for backup/restore compliance

### Building for Production

#### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

#### Signing
- Configure signing in `android/app/build.gradle`
- Add keystore properties to `android/key.properties`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For technical support or feature requests:
- Create an issue on GitHub
- Contact the development team
- Check the troubleshooting section above

## Privacy

TRIminder is designed with privacy in mind:
- All screen time data is stored locally on your device
- Cloud sync is optional and encrypted
- No personal data is shared with third parties
- See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for detailed information
