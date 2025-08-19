import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_service.dart';
import 'services/persistent_tracker_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Supabase
    await SupabaseService.initialize(
      url: 'https://mgfnwykwlrbxisiltmqe.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZm53eWt3bHJieGlzaWx0bXFlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0MTEzNzYsImV4cCI6MjA3MDk4NzM3Nn0.dM6kl0SfNF8Jw9i0NrLlO8KcsjHbLUVgFEOTYsVL_zM',
    );
    print('Supabase initialized successfully');
  } catch (e) {
    print('Error initializing Supabase: $e');
  }
  
  // Initialize persistent background tracking service
  await PersistentTrackerService.initialize();
  
  // Start background service for continuous tracking
  await PersistentTrackerService.startService();
  
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


