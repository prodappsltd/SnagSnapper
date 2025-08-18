import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Email verification screen shown after user signs up
/// Provides instructions to verify email and options to resend or continue
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResendEnabled = true;
  Timer? _resendTimer;
  int _resendCountdown = 0;
  Timer? _checkVerificationTimer;

  @override
  void initState() {
    super.initState();
    // Start checking for email verification
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _checkVerificationTimer?.cancel();
    super.dispose();
  }

  /// Periodically check if email has been verified
  void _startVerificationCheck() {
    _checkVerificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.reload();
          if (user.emailVerified) {
            timer.cancel();
            if (mounted) {
              // Email verified - navigate to profile screen
              // Use the existing Profile screen for new users
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/profile',  // Use existing Profile screen
                (route) => false,
              );
            }
          }
        }
      },
    );
  }

  /// Resend verification email
  Future<void> _resendVerificationEmail() async {
    if (!_isResendEnabled) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Verification email sent!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        // Start countdown
        setState(() {
          _isResendEnabled = false;
          _resendCountdown = 60;
        });

        _resendTimer = Timer.periodic(
          const Duration(seconds: 1),
          (timer) {
            if (_resendCountdown > 0) {
              setState(() {
                _resendCountdown--;
              });
            } else {
              timer.cancel();
              setState(() {
                _isResendEnabled = true;
              });
            }
          },
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resending verification email: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend email. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Continue without verification (for testing)
  void _continueWithoutVerification() {
    if (kDebugMode) {
      // Only allow in debug mode for testing
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/profile',  // Use existing Profile screen
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                          MediaQuery.of(context).padding.top - 
                          MediaQuery.of(context).padding.bottom - 48, // Account for padding
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SizedBox(height: 40),
              
              // Icon
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 60,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Verify Your Email',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle with email
              Text(
                'We\'ve sent a verification link to',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                user?.email ?? 'your email',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please check your email and click the verification link to activate your account.',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.autorenew,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Checking automatically every 5 seconds',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Once you click the link, this screen will automatically proceed.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40), // Replace Spacer with fixed height
              
              // Resend button
              ElevatedButton.icon(
                onPressed: _isResendEnabled ? _resendVerificationEmail : null,
                icon: const Icon(Icons.refresh),
                label: Text(
                  _isResendEnabled 
                    ? 'Resend Verification Email' 
                    : 'Resend in $_resendCountdown seconds',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Try Login button (if verification isn't working)
              OutlinedButton.icon(
                onPressed: () {
                  _checkVerificationTimer?.cancel();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Try Login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Help text
              Text(
                'Already verified? Try logging in with your credentials.',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onBackground.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              
              // Debug only - skip verification
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _continueWithoutVerification,
                  child: Text(
                    'Skip Verification (Debug Only)',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}