import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/persistent_tracker_service.dart';
import 'services/first_time_setup_service.dart';
import 'services/supabase_service.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize secure configuration
  await AppConfig.initialize();
  
  try {
    // Initialize Supabase with secure configuration
    await SupabaseService.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    // Perform first-time setup
    await FirstTimeSetupService.performFirstTimeSetup();

  } catch (e) {
    print('Error initializing Supabase: $e');
  }
  
  // Initialize persistent background tracking service
  await PersistentTrackerService.initialize();
  
  // Note: Sync service will be initialized after user login
  
  runApp(const TRIminderApp());
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


