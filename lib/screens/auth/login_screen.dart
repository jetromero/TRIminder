import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import '../../services/evsu_email_service.dart';
import '../../services/password_reset_service.dart';
import '../../services/user_session_manager.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/auth_error_handler.dart';
import '../../utils/usage_stats_helper.dart';
import 'signup_screen.dart';
import '../dashboard/home_screen.dart';

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
          
          // Check if user signed up today (new user)
          final user = response.user!;
          final isNewUser = DateTime.now().difference(DateTime.parse(user.createdAt)).inDays == 0;
          
          // Set UsageStats permission prompt as pending (will show after navigation)
          // Only prompt if permission is not already granted
          final hasUsageStatsPermission = await UsageStatsHelper.isUsageStatsPermissionGranted();
          if (!hasUsageStatsPermission) {
            await UsageStatsHelper.setPromptPending();
          }
          
          // Navigate to home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(isNewUser: isNewUser),
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

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
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
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: ResponsiveUtils.getScreenPadding(context),
      ),
    );
  }

  Future<void> _showForgotPasswordSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ForgotPasswordFlowSheet(
          initialEmail: _emailController.text.trim(),
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      _showInfoMessage('Password updated. Please log in with your new password.');
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
                    Image.asset(
                      'assets/Images/app/app_icon.png',
                      width: ResponsiveUtils.getIconSize(context, mobile: 80, tablet: 100, desktop: 120),
                      height: ResponsiveUtils.getIconSize(context, mobile: 80, tablet: 100, desktop: 120),
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context)),
                    Text(
                      'TRIminder',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFa92d35),
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
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
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
                          'LOGIN',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context)),

                // Forgot Password
                TextButton(
                  onPressed: _isLoading ? null : _showForgotPasswordSheet,
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

class ForgotPasswordFlowSheet extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordFlowSheet({required this.initialEmail});

  @override
  State<ForgotPasswordFlowSheet> createState() => _ForgotPasswordFlowSheetState();
}

enum _ResetStep { email, otp, password, success }

class _ForgotPasswordFlowSheetState extends State<ForgotPasswordFlowSheet> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _emailController = TextEditingController(text: widget.initialEmail);
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _otpError;

  _ResetStep _step = _ResetStep.email;
  bool _isProcessing = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() {
          _resendSeconds = 0;
        });
      } else {
        setState(() {
          _resendSeconds--;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isProcessing = true;
    });

    try {
      await PasswordResetService.sendOtp(_emailController.text.trim());
      if (!mounted) return;
      _startResendTimer();
      setState(() {
        _step = _ResetStep.otp;
        _isProcessing = false;
        _otpError = null;
      });
      _showSheetMessage('Verification code sent to your EVSU email.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      _showSheetMessage(AuthErrorHandler.getErrorMessage(e), isError: true);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isProcessing = true;
    });

    try {
      await PasswordResetService.verifyOtp(
        email: _emailController.text.trim(),
        token: _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _step = _ResetStep.password;
        _isProcessing = false;
        _otpError = null;
      });
      _showSheetMessage('OTP verified. Choose a new password.');
    } catch (e) {
      // print('ForgotPasswordFlowSheet _verifyOtp error: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _otpError = AuthErrorHandler.getErrorMessage(e);
      });
      _showSheetMessage(_otpError!, isError: true);
    }
  }

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isProcessing = true;
    });

    try {
      await PasswordResetService.updatePassword(_passwordController.text.trim());
      if (!mounted) return;
      setState(() {
        _step = _ResetStep.success;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      _showSheetMessage(AuthErrorHandler.getErrorMessage(e), isError: true);
    }
  }

  void _showSheetMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reset Password',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your EVSU email address to receive a verification code.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'EVSU Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) => EVSUEmailService.validateEmailForLogin(value ?? ''),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _sendOtp,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Send Code',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter Verification Code',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to ${_emailController.text.trim()}.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              prefixIcon: Icon(Icons.verified_outlined),
              border: OutlineInputBorder(),
              counterText: '',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter the verification code.';
              }
              if (value.trim().length != 6) {
                return 'Code must be 6 digits.';
              }
              return null;
            },
          ),
          if (_otpError != null) ...[
            const SizedBox(height: 6),
            Text(
              _otpError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _resendSeconds > 0 || _isProcessing
                ? null
                : () async {
                    await _sendOtp();
                  },
            child: Text(
              _resendSeconds > 0 ? 'Resend code in $_resendSeconds s' : 'Resend Code',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _step = _ResetStep.email;
                          });
                        },
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _verifyOtp,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Verify Code',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Create New Password',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a strong password for your account.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: !_showNewPassword,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () {
                  setState(() {
                    _showNewPassword = !_showNewPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter a password.';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () {
                  setState(() {
                    _showConfirmPassword = !_showConfirmPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _step = _ResetStep.otp;
                          });
                        },
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _updatePassword,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 64,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        Text(
          'Password Updated',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: () {
          switch (_step) {
            case _ResetStep.email:
              return KeyedSubtree(
                key: const ValueKey<_ResetStep>(_ResetStep.email),
                child: _buildEmailStep(),
              );
            case _ResetStep.otp:
              return KeyedSubtree(
                key: const ValueKey<_ResetStep>(_ResetStep.otp),
                child: _buildOtpStep(),
              );
            case _ResetStep.password:
              return KeyedSubtree(
                key: const ValueKey<_ResetStep>(_ResetStep.password),
                child: _buildPasswordStep(),
              );
            case _ResetStep.success:
              return KeyedSubtree(
                key: const ValueKey<_ResetStep>(_ResetStep.success),
                child: _buildSuccessStep(),
              );
          }
        }(),
      ),
    );
  }
}
