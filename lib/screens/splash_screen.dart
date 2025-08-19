import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/user_session_manager.dart';
import 'auth/login_screen.dart';
import 'dashboard/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Add a small delay for splash screen visibility
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // Check if user is authenticated
      final isAuthenticated = SupabaseService().isAuthenticated;
      
      if (isAuthenticated) {
        // User is logged in, initialize session and go to dashboard
        final userId = SupabaseService().currentUserId;
        if (userId != null) {
          await UserSessionManager().initializeUserSession(userId);
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          }
        } else {
          // Fallback to login if user ID is null
          _navigateToLogin();
        }
      } else {
        // User is not authenticated, go to login
        _navigateToLogin();
      }
    } catch (e) {
      print('Error checking authentication: $e');
      // On error, go to login
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Icon(
              Icons.schedule,
              size: 120,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            
            // App Title
            Text(
              'TRIminder',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Digital Wellness & Screen Time Tracker',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            
            // Loading indicator
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            
            // Loading text
            Text(
              'Checking authentication...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
