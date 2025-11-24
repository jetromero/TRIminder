import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/home_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/evsu_email_service.dart';
import '../../services/user_session_manager.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/auth_error_handler.dart';
import '../../utils/input_validator.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedDepartment;
  String? _selectedGender;
  String? _selectedYearLevel;
  DateTime? _selectedDateOfBirth;
  bool _isValidatingEmail = false;

  // List of EVSU departments (matching your Supabase database)
  final List<String> _departments = [
    'Computer Studies',
    'Engineering',
    'Business and Management',
    'Teacher Education',
    'Industrial Technology',
  ];

  // Gender options
  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  // Year level options
  final List<String> _yearLevels = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentIdController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  Future<String?> _validateEmailAsync(String email) async {
    if (email.trim().isEmpty) return null;
    
    setState(() {
      _isValidatingEmail = true;
    });
    
    try {
      String? error = await EVSUEmailService.validateEmailForSignup(email);
      return error;
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingEmail = false;
        });
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
        // Format date for display
        final months = ['January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'];
        _dateOfBirthController.text = '${months[picked.month - 1]} ${picked.day}, ${picked.year}';
      });
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your department'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedYearLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your year level'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Final email validation before signup
    String? emailError = await _validateEmailAsync(_emailController.text);
    if (emailError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(emailError),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Real Supabase user creation
      final response = await SupabaseService().signUpWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        department: _selectedDepartment!,
        studentId: _studentIdController.text.trim(),
        gender: _selectedGender!,
        yearLevel: _selectedYearLevel!,
        dateOfBirth: _selectedDateOfBirth!,
      );

      if (mounted) {
        if (response.user != null) {
          // Check if email confirmation is required
          if (response.user!.emailConfirmedAt == null) {
            // Email confirmation required - show dialog instead of navigating away
            _showEmailConfirmationDialog(_emailController.text);
          } else {
            // Email already confirmed (shouldn't happen with email confirmation enabled)
            await UserSessionManager().initializeUserSession(response.user!.id);
            
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(isNewUser: true),
              ),
            );
          }
        } else {
          // Show generic error if no user but no exception thrown
          _showErrorMessage('Failed to create account. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        // Parse the error and show user-friendly message
        final errorMessage = AuthErrorHandler.getSignupErrorMessage(e);
        _showErrorMessage(errorMessage);
        
        // If error suggests user should login instead, show additional action
        if (AuthErrorHandler.shouldSuggestLogin(e)) {
          _showLoginSuggestion();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Show error message with appropriate styling
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: ResponsiveUtils.getIconSize(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14 * ResponsiveUtils.getFontScale(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: ResponsiveUtils.getScreenPadding(context),
      ),
    );
  }

  /// Show email confirmation dialog with resend option
  void _showEmailConfirmationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.email_outlined, color: Colors.blue, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text('Check Your Email', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('We\'ve sent a confirmation link to:', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                child: Text(email, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
              ),
              SizedBox(height: 16),
              Text('Click the confirmation link in your email to verify your account. You\'ll be automatically redirected to the login screen.', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              SizedBox(height: 12),
              Text('Didn\'t receive the email? Check your spam folder or resend it.', style: TextStyle(fontSize: 14, color: Colors.orange.shade700)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close', style: TextStyle(color: Colors.grey.shade700)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resendConfirmation(email);
              },
              child: Text('Resend Email', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  /// Resend email confirmation
  Future<void> _resendConfirmation(String email) async {
    try {
      await SupabaseService().client.auth.resend(type: OtpType.signup, email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Confirmation email resent to $email. Please check your inbox.'), backgroundColor: Colors.green, duration: Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = AuthErrorHandler.getErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend confirmation: $errorMessage'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Show login suggestion dialog
  void _showLoginSuggestion() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.login_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getIconSize(context, mobile: 24, tablet: 26, desktop: 28),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context)),
                Expanded(
                  child: Text(
                    'Account Already Exists',
                    style: TextStyle(
                      fontSize: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 20) * 
                                ResponsiveUtils.getFontScale(context),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'It looks like you already have an account with this email. Would you like to login instead?',
              style: TextStyle(
                fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * 
                          ResponsiveUtils.getFontScale(context),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14 * ResponsiveUtils.getFontScale(context),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to login
                },
                child: Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 14 * ResponsiveUtils.getFontScale(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Account',
          style: TextStyle(
            fontSize: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 20) * ResponsiveUtils.getFontScale(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: ResponsiveUtils.getMaxContentWidth(context),
            ),
            child: SingleChildScrollView(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                // Welcome Text
                Text(
                  'Join TRIminder',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: (Theme.of(context).textTheme.headlineMedium?.fontSize ?? 28) * ResponsiveUtils.getFontScale(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 12, desktop: 16)),
                Text(
                  'Start your digital wellness journey today!',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) * ResponsiveUtils.getFontScale(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 32, tablet: 40, desktop: 48)),

                // First Name Field
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Your first name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your first name';
                    }
                    final error = InputValidator.validateName(value.trim());
                    if (error != null) {
                      return error;
                    }
                    if (value.trim().length < 2) {
                      return 'First name must be at least 2 characters';
                    }
                    if (value.trim().length > 50) {
                      return 'First name must be 50 characters or less';
                    }
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Last Name Field
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.person_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Your last name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your last name';
                    }
                    final error = InputValidator.validateName(value.trim());
                    if (error != null) {
                      return error;
                    }
                    if (value.trim().length < 2) {
                      return 'Last name must be at least 2 characters';
                    }
                    if (value.trim().length > 50) {
                      return 'Last name must be 50 characters or less';
                    }
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'EVSU Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    suffixIcon: _isValidatingEmail 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(14.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.school_outlined),
                    border: const OutlineInputBorder(),
                    helperText: 'Use your EVSU student email address',
                    hintText: 'student@evsu.edu.ph',
                  ),
                  validator: (value) => EVSUEmailService.validateEmailForLogin(value ?? ''),
                  onChanged: (value) {
                    // Auto-suggest EVSU domain
                    if (value.isNotEmpty && !value.contains('@')) {
                      // Could add auto-suggestion logic here
                    }
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Department Dropdown
                DropdownButtonFormField<String>(
                                      initialValue: _selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.school_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Select your academic department',
                  ),
                  items: _departments.map((String department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Text(department),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDepartment = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your department';
                    }
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Student ID Field
                TextFormField(
                  controller: _studentIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                    LengthLimitingTextInputFormatter(10), // YYYY-XXXXX = 10 chars (including hyphen)
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      // Remove all non-digits
                      final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
                      
                      // Limit to 9 digits (4 for year + 5 for student number)
                      final limitedDigits = digitsOnly.length > 9 
                          ? digitsOnly.substring(0, 9) 
                          : digitsOnly;
                      
                      // Format: add hyphen after 4th digit
                      if (limitedDigits.length <= 4) {
                        return TextEditingValue(
                          text: limitedDigits,
                          selection: TextSelection.collapsed(offset: limitedDigits.length),
                        );
                      } else {
                        final formatted = '${limitedDigits.substring(0, 4)}-${limitedDigits.substring(4)}';
                        return TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    }),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Format: YYYY-XXXXX (e.g., 2020-30041)',
                    hintText: '2020-30041',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your student ID';
                    }
                    return InputValidator.validateStudentId(value.trim());
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    helperText: 'Select your gender',
                  ),
                  items: _genders.map((String gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your gender';
                    }
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Year Level Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedYearLevel,
                  decoration: const InputDecoration(
                    labelText: 'Year Level',
                    prefixIcon: Icon(Icons.school_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Select your current year level',
                  ),
                  items: _yearLevels.map((String year) {
                    return DropdownMenuItem<String>(
                      value: year,
                      child: Text(year),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedYearLevel = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your year level';
                    }
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Date of Birth Field
                TextFormField(
                  controller: _dateOfBirthController,
                  readOnly: true,
                  onTap: _selectDateOfBirth,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                    helperText: 'Tap to select your date of birth',
                  ),
                  validator: (value) {
                    if (_selectedDateOfBirth == null) {
                      return 'Please select your date of birth';
                    }
                    return InputValidator.validateDateOfBirth(_selectedDateOfBirth);
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: _togglePasswordVisibility,
                    ),
                    border: const OutlineInputBorder(),
                    helperText: 'At least 6 characters',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: _toggleConfirmPasswordVisibility,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 32, tablet: 40, desktop: 48)),

                // Signup Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Terms and Privacy
                Text(
                  'By creating an account, you agree to our Terms of Service and Privacy Policy',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 24, tablet: 28, desktop: 32)),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
