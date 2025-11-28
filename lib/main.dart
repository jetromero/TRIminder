import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'screens/splash_screen.dart';
import 'screens/error_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/persistent_tracker_service.dart';
import 'services/first_time_setup_service.dart';
import 'services/supabase_service.dart';
import 'config/app_config.dart';

void main() async {
  // Set up global error handling
  _setupErrorHandling();
  
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Start the app immediately to avoid blocking the UI
    runApp(const TRIminderApp());
    
    // Initialize services in background to improve startup performance
    _initializeServicesInBackground();
  } catch (e, stackTrace) {
    print('❌ Critical error in main(): $e');
    print('Stack trace: $stackTrace');
    
    // Show error screen if main initialization fails
    runApp(MaterialApp(
      home: ErrorScreen(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        isCritical: true,
      ),
    ));
  }
}

/// Set up global error handling for Flutter and platform errors
void _setupErrorHandling() {
  // Handle Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    print('❌ Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
    
    // Log to crash analytics if available
    _logError('Flutter Error', details.exception.toString(), details.stack.toString());
  };

  // Handle platform errors (Android/iOS)
  PlatformDispatcher.instance.onError = (error, stack) {
    print('❌ Platform Error: $error');
    print('Stack trace: $stack');
    
    // Log to crash analytics if available
    _logError('Platform Error', error.toString(), stack.toString());
    
    return true; // Mark as handled
  };
}

/// Log errors for debugging (can be extended with crash analytics)
void _logError(String type, String error, String stackTrace) {
  // TODO: Add crash analytics integration (Firebase Crashlytics, Sentry, etc.)
  print('📊 Error Log - Type: $type');
  print('📊 Error: $error');
  print('📊 Stack: $stackTrace');
}

/// Initialize services in background to prevent UI blocking
void _initializeServicesInBackground() async {
  print('🚀 Starting background service initialization...');
  
  // Initialize each service independently to prevent cascade failures
  await _initializeService('AppConfig', () async {
    await AppConfig.initialize();
  });
  
  await _initializeService('Supabase', () async {
    await SupabaseService.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  });
  
  await _initializeService('FirstTimeSetup', () async {
    await FirstTimeSetupService.performFirstTimeSetup();
  });
  
  await _initializeService('PersistentTracker', () async {
    await PersistentTrackerService.initialize();
  });
  
  print('✅ Service initialization completed');
}

/// Initialize a single service with error handling
Future<void> _initializeService(String serviceName, Future<void> Function() initFunction) async {
  try {
    print('🔄 Initializing $serviceName...');
    await initFunction();
    print('✅ $serviceName initialized successfully');
  } catch (e, stackTrace) {
    print('❌ Failed to initialize $serviceName: $e');
    print('Stack trace: $stackTrace');
    
    // Log the error for debugging
    _logError('Service Initialization Error', '$serviceName: $e', stackTrace.toString());
    
    // Continue with other services even if one fails
    print('⚠️ Continuing with other services despite $serviceName failure');
  }
}


class TRIminderApp extends StatefulWidget {
  const TRIminderApp({super.key});

  @override
  State<TRIminderApp> createState() => _TRIminderAppState();
}

class _TRIminderAppState extends State<TRIminderApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinkListener();
  }

  void _initDeepLinkListener() {
    // Only listen for real-time deep links (when app is running)
    // Don't process getInitialLink() for email confirmation as it may be stale
    // Email confirmation links should only be processed when clicked in real-time
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        print('🔗 Real-time deep link received: $uri');
        _handleDeepLink(uri, isRealTime: true);
      },
      onError: (err) {
        print('Error handling deep link: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri, {bool isRealTime = false}) {
    print('🔗 Deep link received: $uri (real-time: $isRealTime)');
    
    if (uri.scheme == 'triminder' && uri.host == 'auth-callback') {
      // Only process email confirmation links if they're real-time (just clicked)
      // Ignore stale links from getInitialLink() to prevent false positives
      if (!isRealTime) {
        print('⚠️ Ignoring stale deep link - only processing real-time email confirmations');
        return;
      }
      
      // Email confirmation callback - close any dialogs and navigate to login
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        // Close any open dialogs first by popping until we reach the first route
        // This will close any AlertDialogs or other modal routes
        while (navigator.canPop()) {
          navigator.pop();
        }
        
        // Navigate to login screen, removing all previous routes
        Future.delayed(const Duration(milliseconds: 300), () {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
            
            // Show success message after navigation
            Future.delayed(const Duration(milliseconds: 500), () {
              final context = navigatorKey.currentContext;
              if (context != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email confirmed! You can now log in.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'TRIminder',
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFFFFFF),       // White
          onPrimary: Color(0xFFa92d35),     // Red text on white
          secondary: Color(0xFFaeaeae),     // Gray
          onSecondary: Color(0xFF000000),   // Black text on gray
          tertiary: Color(0xFFa92d35),      // Red accent
          surface: Color(0xFFFFFFFF),       // White surface
          onSurface: Color(0xFF212121),     // Dark text
          surfaceContainerHighest: Color(0xFFF5F5F5), // Light gray cards
          outline: Color(0xFFaeaeae),       // Gray borders
          error: Color(0xFFa92d35),         // Red for errors
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFFa92d35),
          iconTheme: IconThemeData(color: Color(0xFFa92d35)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFa92d35),
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFa92d35),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFa92d35),
            side: const BorderSide(color: Color(0xFFaeaeae)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          floatingLabelStyle: const TextStyle(color: Color(0xFFa92d35)),
          labelStyle: const TextStyle(color: Color(0xFFaeaeae)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFaeaeae)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFaeaeae)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFa92d35), width: 2),
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFFa92d35),
          selectionColor: Color(0x40a92d35),
          selectionHandleColor: Color(0xFFa92d35),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFa92d35),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFFa92d35),
          unselectedItemColor: Color(0xFFaeaeae),
          showUnselectedLabels: true,
        ),
        navigationDrawerTheme: const NavigationDrawerThemeData(
          indicatorColor: Color(0x30a92d35),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFF5F5F5),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// This file now only contains the main app configuration
// The actual screens are in the screens/ directory


