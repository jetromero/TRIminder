import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/persistent_tracker_service.dart';
import 'services/first_time_setup_service.dart';
import 'services/supabase_service.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the app immediately to avoid blocking the UI
  runApp(const TRIminderApp());
  
  // Initialize services in background to improve startup performance
  _initializeServicesInBackground();
}

/// Initialize services in background to prevent UI blocking
void _initializeServicesInBackground() async {
  try {
    // Initialize secure configuration
    await AppConfig.initialize();
    
    // Initialize Supabase with secure configuration
    await SupabaseService.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    // Perform first-time setup
    await FirstTimeSetupService.performFirstTimeSetup();

    // Initialize persistent background tracking service
    await PersistentTrackerService.initialize();
    
    print('✅ All services initialized successfully');
  } catch (e) {
    print('❌ Error initializing services: $e');
  }
}


class TRIminderApp extends StatelessWidget {
  const TRIminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TRIminder',
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3), // Blue primary color
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// This file now only contains the main app configuration
// The actual screens are in the screens/ directory


