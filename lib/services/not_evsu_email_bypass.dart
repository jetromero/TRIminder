class NotEVSUEmailBypass {
  /// Check if the provided email is a Gmail address
  /// 
  /// The email is normalized (lowercase, trimmed) before checking.
  /// Supports Gmail addresses with dots, plus signs, and hyphens.
  /// Examples: test@gmail.com, test.email@gmail.com, test+tag@gmail.com
  static bool isGmail(String email) {
    if (email.isEmpty) return false;
    
    // Normalize email: lowercase and trim whitespace
    email = email.toLowerCase().trim();
    
    // Check if it ends with @gmail.com
    if (!email.endsWith('@gmail.com')) {
      return false;
    }
    
    // Extract local part (before @)
    final parts = email.split('@');
    if (parts.length != 2) {
      return false;
    }
    
    final localPart = parts[0];
    
    // Gmail local part rules:
    // - Must be at least 1 character
    // - Can contain: letters (a-z), numbers (0-9), dots (.), plus signs (+), hyphens (-), underscores (_)
    // - Cannot start or end with a dot
    // - Cannot have consecutive dots
    if (localPart.isEmpty) {
      return false;
    }
    
    // Check if it contains only valid characters
    final validCharsRegex = RegExp(r'^[a-z0-9.+_-]+$');
    if (!validCharsRegex.hasMatch(localPart)) {
      return false;
    }
    
    // Cannot start or end with a dot
    if (localPart.startsWith('.') || localPart.endsWith('.')) {
      return false;
    }
    
    // Cannot have consecutive dots
    if (localPart.contains('..')) {
      return false;
    }
    
    return true;
  }
}