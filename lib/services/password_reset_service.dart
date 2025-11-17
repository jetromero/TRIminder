import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/input_validator.dart';
import 'evsu_email_service.dart';
import 'supabase_service.dart';

class PasswordResetService {
  static DateTime? _lastOtpRequestAttempt;
  static int _otpRequestAttempts = 0;
  static const int _maxOtpAttempts = 3;
  static const Duration _otpCooldown = Duration(minutes: 2);

  static bool _isOtpRateLimited() {
    if (_lastOtpRequestAttempt == null) return false;

    final elapsed = DateTime.now().difference(_lastOtpRequestAttempt!);
    if (elapsed >= _otpCooldown) {
      _otpRequestAttempts = 0;
      return false;
    }
    return _otpRequestAttempts >= _maxOtpAttempts;
  }

  static Future<void> sendOtp(String email) async {
    _validateEmail(email);
    if (_isOtpRateLimited()) {
      throw Exception('Too many verification code requests. Please wait and try again.');
    }

    final sanitizedEmail = InputValidator.sanitizeInput(email.toLowerCase());
    try {
      _otpRequestAttempts++;
      _lastOtpRequestAttempt = DateTime.now();

      await SupabaseService().client.auth.signInWithOtp(
            email: sanitizedEmail,
            shouldCreateUser: false,
          );
    } catch (e) {
      if (DateTime.now().difference(_lastOtpRequestAttempt!).inSeconds < 5) {
        _otpRequestAttempts = (_otpRequestAttempts - 1).clamp(0, _maxOtpAttempts);
      }
      rethrow;
    }
  }

  static Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    _validateEmail(email);
    if (token.trim().isEmpty) {
      throw Exception('Please enter the verification code.');
    }

    final sanitizedEmail = InputValidator.sanitizeInput(email.toLowerCase());
    final sanitizedToken = InputValidator.sanitizeInput(token);

    try {
      final response = await SupabaseService().client.auth.verifyOTP(
            email: sanitizedEmail,
            token: sanitizedToken,
            type: OtpType.email,
          );

      if (response.session == null) {
        throw Exception('Incorrect or expired verification code. Please try again.');
      }

      return response;
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('invalid') || message.contains('expired') || message.contains('otp')) {
        throw Exception('Incorrect or expired verification code. Please try again.');
      }
      rethrow;
    }
  }

  static Future<void> updatePassword(String newPassword) async {
    final passwordError = InputValidator.validatePassword(newPassword);
    if (passwordError != null) {
      throw Exception(passwordError);
    }

    final response = await SupabaseService().client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

    if (response.user == null) {
      throw Exception('Unable to update password. Please try again.');
    }

    await SupabaseService().signOut();
  }

  static void _validateEmail(String email) {
    final baseError = EVSUEmailService.validateEmailForLogin(email);
    if (baseError != null) {
      throw Exception(baseError);
    }
  }
}

