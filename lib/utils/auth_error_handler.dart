import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility class for handling authentication errors with user-friendly messages
class AuthErrorHandler {
  
  /// Parse Supabase authentication error and return user-friendly message
  static String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      switch (error.statusCode) {
        case '400':
          if (error.message.toLowerCase().contains('invalid')) {
            return 'Invalid email or password. Please check your credentials.';
          }
          if (error.message.toLowerCase().contains('email')) {
            return 'Please enter a valid email address.';
          }
          if (error.message.toLowerCase().contains('password')) {
            return 'Password must be at least 6 characters long.';
          }
          return 'Invalid login credentials. Please try again.';
        
        case '401':
          return 'Incorrect email or password. Please try again.';
        
        case '422':
          if (error.message.toLowerCase().contains('email')) {
            return 'This email address is not registered. Please sign up first.';
          }
          return 'Login credentials are invalid. Please check and try again.';
        
        case '429':
          return 'Too many login attempts. Please wait a moment and try again.';
        
        case '500':
          return 'Server error. Please try again later.';
        
        default:
          // Check for specific error messages
          final message = error.message.toLowerCase();
          
          if (message.contains('invalid login credentials') || 
              message.contains('invalid email or password')) {
            return 'Incorrect email or password. Please try again.';
          }
          
          if (message.contains('email not confirmed')) {
            return 'Please check your email and confirm your account before logging in.';
          }
          
          if (message.contains('user not found')) {
            return 'No account found with this email. Please sign up first.';
          }
          
          if (message.contains('password')) {
            return 'Incorrect password. Please try again.';
          }
          
          if (message.contains('email')) {
            return 'Email not found. Please check your email address.';
          }
          
          if (message.contains('network') || message.contains('connection')) {
            return 'Network error. Please check your internet connection.';
          }
          
          // Return the original message if we can't parse it
          return error.message.isNotEmpty 
              ? 'Login failed: ${error.message}' 
              : 'Login failed. Please try again.';
      }
    }
    
    // Handle other types of errors
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    
    // Default fallback
    return 'Login failed. Please check your credentials and try again.';
  }

  /// Parse signup errors
  static String getSignupErrorMessage(dynamic error) {
    if (error is AuthException) {
      switch (error.statusCode) {
        case '400':
          if (error.message.toLowerCase().contains('already registered') ||
              error.message.toLowerCase().contains('already exists')) {
            return 'This email is already registered. Please login instead.';
          }
          if (error.message.toLowerCase().contains('password')) {
            return 'Password must be at least 6 characters long.';
          }
          if (error.message.toLowerCase().contains('email')) {
            return 'Please enter a valid email address.';
          }
          return 'Invalid signup information. Please check your details.';
        
        case '422':
          if (error.message.toLowerCase().contains('email')) {
            return 'This email is already in use. Please use a different email or login.';
          }
          return 'Signup failed. Please check your information and try again.';
        
        case '429':
          return 'Too many signup attempts. Please wait a moment and try again.';
        
        default:
          final message = error.message.toLowerCase();
          
          if (message.contains('already') || message.contains('exists')) {
            return 'This email is already registered. Please login instead.';
          }
          
          if (message.contains('password')) {
            return 'Password must be at least 6 characters long.';
          }
          
          return error.message.isNotEmpty 
              ? 'Signup failed: ${error.message}' 
              : 'Signup failed. Please try again.';
      }
    }
    
    return 'Signup failed. Please check your information and try again.';
  }

  /// Check if error indicates user should sign up instead
  static bool shouldSuggestSignup(dynamic error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      return message.contains('user not found') || 
             message.contains('email not found') ||
             message.contains('not registered');
    }
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('user not found') ||
           errorString.contains('email not found') ||
           errorString.contains('not registered');
  }

  /// Check if error indicates user should login instead
  static bool shouldSuggestLogin(dynamic error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      return message.contains('already registered') || 
             message.contains('already exists') ||
             message.contains('email is already');
    }
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('already registered') ||
           errorString.contains('already exists') ||
           errorString.contains('email is already');
  }
}
