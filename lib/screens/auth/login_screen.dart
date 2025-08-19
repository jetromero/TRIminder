import 'package:flutter/material.dart';
import 'signup_screen.dart';
import '../dashboard/home_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/evsu_email_service.dart';
import '../../services/user_session_manager.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/auth_error_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Real Supabase authentication
      final response = await SupabaseService().signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        if (response.user != null) {
          // Success - initialize user session
          await UserSessionManager().initializeUserSession(response.user!.id);
          
          // Navigate to home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        } else {
          // Show generic error if no user but no exception thrown
          _showErrorMessage('Login failed. Please check your credentials.');
        }
      }
    } catch (e) {
      if (mounted) {
        // Parse the error and show user-friendly message
        final errorMessage = AuthErrorHandler.getErrorMessage(e);
        _showErrorMessage(errorMessage);
        
        // If error suggests user should sign up, show additional action
        if (AuthErrorHandler.shouldSuggestSignup(e)) {
          _showSignupSuggestion();
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

  void _goToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SignupScreen(),
      ),
    );
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

  /// Show signup suggestion dialog
  void _showSignupSuggestion() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.person_add_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getIconSize(context, mobile: 24, tablet: 26, desktop: 28),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context)),
                Expanded(
                  child: Text(
                    'Account Not Found',
                    style: TextStyle(
                      fontSize: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 20) * 
                                ResponsiveUtils.getFontScale(context),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'It looks like you don\'t have an account yet. Would you like to create one?',
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
                  _goToSignup();
                },
                child: Text(
                  'Sign Up',
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                // App Logo and Title
                Column(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: ResponsiveUtils.getIconSize(context, mobile: 80, tablet: 100, desktop: 120),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context)),
                    Text(
                      'TRIminder',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: (Theme.of(context).textTheme.headlineLarge?.fontSize ?? 32) * ResponsiveUtils.getFontScale(context),
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 12, desktop: 16)),
                    Text(
                      'Digital Wellness & Screen Time Tracker',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) * ResponsiveUtils.getFontScale(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 48, tablet: 56, desktop: 64)),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'EVSU Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Use your EVSU email address',
                    hintText: 'student@evsu.edu.ph',
                  ),
                  validator: (value) => EVSUEmailService.validateEmailForLogin(value ?? ''),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
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
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 24, tablet: 28, desktop: 32)),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
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
                          'Login',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Forgot Password
                TextButton(
                  onPressed: _isLoading ? null : () {
                    // TODO: Implement forgot password
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Forgot password feature coming soon!'),
                      ),
                    );
                  },
                  child: const Text('Forgot Password?'),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 24, tablet: 28, desktop: 32)),

                // Signup Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _goToSignup,
                      child: const Text(
                        'Sign Up',
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
    ));
  }
}
