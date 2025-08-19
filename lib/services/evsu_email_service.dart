
import 'supabase_service.dart';

class EVSUEmailService {
  static final EVSUEmailService _instance = EVSUEmailService._internal();
  factory EVSUEmailService() => _instance;
  EVSUEmailService._internal();

  // List of valid EVSU email domains
  static const List<String> _validDomains = [
    '@evsu.edu.ph',
    '@student.evsu.edu.ph',
  ];

  // Valid department prefixes (commonly used in EVSU emails)
  static const List<String> _validDepartmentPrefixes = [
    'cs', 'coe', 'cte', 'cbm', 'cit', // College codes
    'bsit', 'bscs', 'bsce', 'bsee', 'bsme', // Program codes
    'student', // Generic student
  ];

  /// Validates if email follows EVSU format
  static bool isValidEVSUEmailFormat(String email) {
    email = email.toLowerCase().trim();
    
    // Check if it ends with valid EVSU domain
    bool hasValidDomain = _validDomains.any((domain) => email.endsWith(domain));
    if (!hasValidDomain) return false;

    // Extract username part (before @)
    String username = email.split('@')[0];
    
    // Basic format validation
    if (username.length < 3) return false;
    
    // Check if contains only valid characters (letters, numbers, dots, hyphens)
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(username)) return false;
    
    return true;
  }

  /// Enhanced validation that checks if email exists in our database
  static Future<bool> checkEmailExistsInDatabase(String email) async {
    try {
      final supabaseService = SupabaseService();
      
      // Check if email already exists in profiles table
      final response = await supabaseService.client
          .from('profiles')
          .select('email')
          .eq('email', email.toLowerCase().trim())
          .limit(1);
      
      return response.isNotEmpty;
    } catch (e) {
      print('Error checking email in database: $e');
      return false; // Assume it doesn't exist if we can't check
    }
  }

  /// Comprehensive email validation for signup
  static Future<String?> validateEmailForSignup(String email) async {
    email = email.trim();
    
    // Basic format validation
    if (email.isEmpty) {
      return 'Please enter your email';
    }
    
    // Standard email format check
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    // EVSU format validation
    if (!isValidEVSUEmailFormat(email)) {
      return 'Please use a valid EVSU email address (@evsu.edu.ph)';
    }
    
    // Check if email already exists in database
    try {
      bool emailExists = await checkEmailExistsInDatabase(email);
      if (emailExists) {
        return 'This email is already registered. Please use a different email or login.';
      }
    } catch (e) {
      // If we can't check, allow the signup to proceed
      print('Warning: Could not verify email uniqueness: $e');
    }
    
    return null; // No errors
  }

  /// Validation for login (less strict, just format)
  static String? validateEmailForLogin(String email) {
    email = email.trim();
    
    if (email.isEmpty) {
      return 'Please enter your email';
    }
    
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    if (!isValidEVSUEmailFormat(email)) {
      return 'Please use your EVSU email address (@evsu.edu.ph)';
    }
    
    return null;
  }

  /// Get suggested email format based on partial input
  static String getSuggestedEmail(String partialEmail) {
    if (partialEmail.contains('@')) {
      return partialEmail;
    }
    
    // If no @ symbol, suggest the main domain
    return '$partialEmail@evsu.edu.ph';
  }

  /// Extract student info from email (if possible)
  static Map<String, String?> extractStudentInfo(String email) {
    email = email.toLowerCase().trim();
    String username = email.split('@')[0];
    
    // Try to extract department/program info
    String? department;
    for (String prefix in _validDepartmentPrefixes) {
      if (username.startsWith(prefix)) {
        department = prefix.toUpperCase();
        break;
      }
    }
    
    return {
      'username': username,
      'domain': email.split('@')[1],
      'suggestedDepartment': department,
    };
  }
}
