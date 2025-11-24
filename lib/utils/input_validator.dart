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

  // Student ID validation (format: YYYY-XXXXX, example: "2020-30041")
  static String? validateStudentId(String studentId) {
    if (studentId.isEmpty) return 'Student ID is required';
    
    // Remove spaces for validation
    final cleaned = studentId.replaceAll(' ', '');
    
    // Check format: YYYY-XXXXX (4 digits, hyphen, 5 digits)
    final studentIdRegex = RegExp(r'^\d{4}-\d{5}$');
    if (!studentIdRegex.hasMatch(cleaned)) {
      return 'Student ID must be in format YYYY-XXXXX (e.g., 2020-30041)';
    }
    
    return null;
  }

  // Date of Birth validation
  static String? validateDateOfBirth(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return 'Date of birth is required';
    
    final now = DateTime.now();
    final age = now.year - dateOfBirth.year - (now.month > dateOfBirth.month || 
        (now.month == dateOfBirth.month && now.day >= dateOfBirth.day) ? 0 : 1);
    
    if (age < 16) {
      return 'You must be at least 16 years old';
    }
    
    if (age > 100) {
      return 'Please enter a valid date of birth';
    }
    
    // Check if date is not in the future
    if (dateOfBirth.isAfter(now)) {
      return 'Date of birth cannot be in the future';
    }
    
    return null;
  }

  // Sanitize student ID (remove spaces, preserve hyphen and digits)
  static String sanitizeStudentId(String studentId) {
    return studentId.replaceAll(' ', '').trim();
  }
}