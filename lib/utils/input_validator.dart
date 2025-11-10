import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../config/app_config.dart';
import '../services/not_evsu_email_bypass.dart';

class InputValidator {
  // Email validation
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    
    // Basic email format validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return false;
    
    // Allow Gmail bypass if enabled
    if (AppConfig.allowBypass && NotEVSUEmailBypass.isGmail(email)) {
      return true;
    }
    
    // EVSU domain validation
    final evsuDomains = ['@evsu.edu.ph', '@student.evsu.edu.ph'];
    return evsuDomains.any((domain) => email.toLowerCase().endsWith(domain));
  }
  
  // Password validation
  static String? validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (password.length > 128) return 'Password is too long';
    
    // Check for common weak passwords
    final weakPasswords = ['password', '123456', 'qwerty', 'admin'];
    if (weakPasswords.contains(password.toLowerCase())) {
      return 'Please choose a stronger password';
    }
    
    return null;
  }
  
  // Name validation
  static String? validateName(String name) {
    if (name.isEmpty) return 'Name is required';
    if (name.length < 2) return 'Name must be at least 2 characters';
    if (name.length > 100) return 'Name is too long';
    
    // Check for valid characters only
    final nameRegex = RegExp(r'^[a-zA-Z\s\-\.]+$');
    if (!nameRegex.hasMatch(name)) {
      return 'Name contains invalid characters';
    }
    
    return null;
  }
  
  // Sanitize input
  static String sanitizeInput(String input) {
    return input.trim().replaceAll(RegExp(r'''[<>"]'''), '');
  }
  
  // Hash sensitive data for logging (not for storage)
  static String hashForLogging(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8);
  }
  
  // Rate limiting helper
  static bool isRateLimited(DateTime lastAttempt, Duration cooldown) {
    return DateTime.now().difference(lastAttempt) < cooldown;
  }
}