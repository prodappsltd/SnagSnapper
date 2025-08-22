import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:another_flushbar/flushbar.dart';
import '../../Data/contentProvider.dart';
import '../../Helper/auth.dart';
import '../../Helper/error.dart';
// import '../../services/image_service.dart'; // REMOVED - Service is commented out
// import '../../services/image_preload_service.dart'; // REMOVED - Service is commented out

/// Unified authentication screen that combines login and signup functionality
/// Provides direct access to email/password fields and Google sign-in
/// Includes smooth animations and modern UI design
class UnifiedAuthScreen extends StatefulWidget {
  const UnifiedAuthScreen({super.key});

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen> 
    with SingleTickerProviderStateMixin {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Animation controller for future animations
  late AnimationController _animationController;
  
  // State variables
  bool _isLoginMode = true;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Clean up any cached images on login screen
    // This ensures no data leakage between users
    _cleanupCachedImages();
  }
  
  /// Cleanup any remaining cached images
  Future<void> _cleanupCachedImages() async {
    // DISABLED: ImageService is deprecated
    // TODO: Implement cache clearing with new ImageStorageService if needed
    if (kDebugMode) print('UnifiedAuthScreen: Image cache cleanup disabled (service deprecated)');
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  /// Toggles between login and signup mode
  void _toggleAuthMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      // Clear form when switching modes
      _formKey.currentState?.reset();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    
    // TODO: Add slide animation when switching modes
  }
  
  /// Handles email/password authentication
  Future<void> _handleEmailPasswordAuth() async {
    // Prevent double submission
    if (_isLoading) {
      if (kDebugMode) print('UnifiedAuthScreen: Already processing, ignoring duplicate submission');
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    // Debug logging
    if (kDebugMode) {
      print('UnifiedAuthScreen: Starting ${_isLoginMode ? "login" : "signup"} process');
      print('Email: ${_emailController.text}');
    } else {
      // Production breadcrumb
      FirebaseCrashlytics.instance.log('Auth attempt: ${_isLoginMode ? "login" : "signup"}');
    }
    
    try {
      final auth = Auth();
      Information result;
      
      if (_isLoginMode) {
        // Login flow
        if (kDebugMode) {
          print('Attempting login for: ${_emailController.text}');
        }
        
        result = await auth.signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );
        
        if (kDebugMode) {
          print('Login result - Error: ${result.error}, Message: ${result.message}');
        }
        
        if (!result.error) {
          // Success - load user profile before navigating
          if (kDebugMode) print('Login successful, loading profile...');
          
          // Load user profile
          final cp = Provider.of<CP>(context, listen: false);
          if (kDebugMode) print('UnifiedAuthScreen: Calling loadProfileOfUser...');
          final profileResult = await cp.loadProfileOfUser();
          if (kDebugMode) print('UnifiedAuthScreen: loadProfileOfUser returned: $profileResult');
          
          if (kDebugMode) {
            print('Profile load result: $profileResult');
          } else {
            // Production breadcrumb
            FirebaseCrashlytics.instance.log('Login profile load result: $profileResult');
          }
          
          if (mounted) {
            if (kDebugMode) print('UnifiedAuthScreen: Mounted, checking profile result...');
            if (profileResult == 'Profile Found') {
              // Image preloading disabled - service is deprecated
              // TODO: Implement preloading with new ImageStorageService if needed
              if (kDebugMode) print('Image preload disabled (service deprecated)');
              
              // Profile exists - navigate to main menu
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/mainMenu',
                (route) => false,
              );
            } else if (profileResult == 'Profile Not Found') {
              // No profile - navigate directly to profile screen
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/profile',
                (route) => false,
              );
            } else {
              // Error loading profile
              if (kDebugMode) {
                print('UnifiedAuthScreen._handleEmailPasswordAuth: Error loading profile - $profileResult');
              }
              _showErrorMessage('Error loading profile: $profileResult');
            }
          }
        } else {
          // Show error - ensure loading state is cleared first
          if (mounted) {
            setState(() => _isLoading = false);
          }
          
          if (kDebugMode) {
            print('UnifiedAuthScreen._handleEmailPasswordAuth: Login auth error - ${result.message}');
          }
          
          // Ensure we have a meaningful error message
          String errorMessage = result.message.isNotEmpty 
              ? result.message 
              : 'Login failed. Please check your credentials.';
          
          _showErrorMessage(errorMessage);
        }
      } else {
        // Signup flow
        result = await auth.createUserWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );
        
        if (!result.error) {
          // Send verification email
          await auth.sendEmailVerification();
          
          if (kDebugMode) print('Signup successful, verification email sent');
          
          // Navigate to email verification screen
          if (mounted) {
            Navigator.of(context).pushNamed('/emailVerification');
          }
        } else {
          // Show error
          if (kDebugMode) {
            print('UnifiedAuthScreen._handleEmailPasswordAuth: Signup error - ${result.message}');
          }
          _showErrorMessage(result.message);
        }
      }
    } catch (e) {
      // Unexpected error
      if (kDebugMode) {
        print('Auth error: $e');
      } else {
        FirebaseCrashlytics.instance.recordError(e, null);
      }
      if (kDebugMode) {
        print('UnifiedAuthScreen._handleEmailPasswordAuth: Unexpected error - Please try again');
      }
      _showErrorMessage('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  /// Shows error message using Flushbar
  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    Flushbar(
      message: message,
      duration: const Duration(seconds: 4),
      backgroundColor: Theme.of(context).colorScheme.error,
      icon: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.onError,
      ),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
    ).show(context);
  }
  
  /// Handles Google sign-in
  Future<void> _handleGoogleSignIn() async {
    // Prevent double submission
    if (_isLoading) {
      if (kDebugMode) print('UnifiedAuthScreen: Already processing, ignoring duplicate Google sign-in');
      return;
    }
    
    setState(() => _isLoading = true);
    
    // Debug logging
    if (kDebugMode) {
      print('UnifiedAuthScreen: Starting Google sign-in');
    } else {
      FirebaseCrashlytics.instance.log('Google sign-in attempt');
    }
    
    try {
      final auth = Auth();
      final result = await auth.signInWithGoogle();
      
      if (!result.error) {
        // Success - load user profile before navigating
        if (kDebugMode) print('Google sign-in successful, loading profile...');
        
        // Load user profile
        final cp = Provider.of<CP>(context, listen: false);
        final profileResult = await cp.loadProfileOfUser();
        
        if (kDebugMode) {
          print('Profile load result: $profileResult');
        } else {
          // Production breadcrumb
          FirebaseCrashlytics.instance.log('Google login profile load result: $profileResult');
        }
        
        if (mounted) {
          if (profileResult == 'Profile Found') {
            // Image preloading disabled - service is deprecated
            // TODO: Implement preloading with new ImageStorageService if needed
            if (kDebugMode) print('Image preload disabled (service deprecated)');
            
            // Profile exists - navigate to main menu
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/mainMenu',
              (route) => false,
            );
          } else if (profileResult == 'Profile Not Found') {
            // No profile - navigate directly to profile screen
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/profile',
              (route) => false,
            );
          } else {
            // Error loading profile
            if (kDebugMode) {
              print('UnifiedAuthScreen._handleGoogleSignIn: Error loading profile - $profileResult');
            }
            _showErrorMessage('Error loading profile: $profileResult');
          }
        }
      } else {
        // Show error
        if (kDebugMode) {
          print('UnifiedAuthScreen._handleGoogleSignIn: Google auth error - ${result.message}');
        }
        _showErrorMessage(result.message);
      }
    } catch (e) {
      // Unexpected error
      if (kDebugMode) {
        print('Google sign-in error: $e');
      } else {
        FirebaseCrashlytics.instance.recordError(e, null);
      }
      if (kDebugMode) {
        print('UnifiedAuthScreen._handleGoogleSignIn: Unexpected error - Failed to sign in with Google');
      }
      _showErrorMessage('Failed to sign in with Google. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // App Logo and Title
                _buildHeader(theme),
                
                const SizedBox(height: 48),
                
                // Email/Password Form
                _buildAuthForm(theme),
                
                const SizedBox(height: 24),
                
                // Submit Button
                _buildSubmitButton(theme),
                
                const SizedBox(height: 16),
                
                // OR Divider
                _buildOrDivider(theme),
                
                const SizedBox(height: 16),
                
                // Google Sign In Button
                _buildGoogleSignInButton(theme),
                
                const SizedBox(height: 24),
                
                // Toggle Auth Mode
                _buildAuthModeToggle(theme),
                
                const SizedBox(height: 40),
                
                // Theme Toggle
                _buildThemeToggle(theme),
                
                const SizedBox(height: 16),
                
                // Theme Settings Button
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/themeSelector'),
                  child: const Text('Theme Settings'),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
  
  /// Builds the header with logo and title
  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        // Logo with hero animation ready
        Hero(
          tag: 'app_logo',
          child: Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'images/1024LowPoly.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            children: [
              TextSpan(
                text: 'S',
                style: GoogleFonts.inter(
                  fontSize: 44.8, // 32 * 1.4
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const TextSpan(text: 'nag'),
              TextSpan(
                text: 'S',
                style: GoogleFonts.inter(
                  fontSize: 44.8, // 32 * 1.4
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const TextSpan(text: 'napper'),
            ],
          ),
        ),
        Text(
          'Your ultimate LIVE SNAG SHARING app',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
  /// Builds the email/password form
  Widget _buildAuthForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: _isLoginMode ? TextInputAction.done : TextInputAction.next,
            onFieldSubmitted: (_) {
              // Only submit if in login mode and not already loading
              if (_isLoginMode && !_isLoading) {
                _handleEmailPasswordAuth();
              }
            },
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (!_isLoginMode && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          
          // Confirm Password Field (Signup only)
          if (!_isLoginMode) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible 
                        ? Icons.visibility_off 
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => 
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleEmailPasswordAuth(),
            ),
          ],
          
          // Forgot Password (Login only)
          if (_isLoginMode)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Navigate to forgot password screen
                  Navigator.pushNamed(context, '/forgotPassword');
                },
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Builds the submit button
  Widget _buildSubmitButton(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: _isLoading ? null : _handleEmailPasswordAuth,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isLoginMode ? 'Sign In' : 'Sign Up',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
  
  /// Builds the OR divider
  Widget _buildOrDivider(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }
  
  /// Builds the Google sign-in button
  Widget _buildGoogleSignInButton(ThemeData theme) {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(
          color: theme.colorScheme.outline,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Google Logo
          SvgPicture.asset(
            'images/google_logo.svg',
            height: 24,
            width: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Continue with Google',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds the auth mode toggle
  Widget _buildAuthModeToggle(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLoginMode 
              ? "Don't have an account?" 
              : "Already have an account?",
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: _toggleAuthMode,
          child: Text(
            _isLoginMode ? 'Sign Up' : 'Sign In',
            style: GoogleFonts.inter(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
  
  /// Builds the theme toggle button
  Widget _buildThemeToggle(ThemeData theme) {
    return Center(
      child: IconButton(
        onPressed: () {
          Provider.of<CP>(context, listen: false).changeBrightness(
            theme.brightness == Brightness.light 
                ? Brightness.dark 
                : Brightness.light,
          );
        },
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
          child: Icon(
            theme.brightness == Brightness.light 
                ? Icons.dark_mode 
                : Icons.light_mode,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
      ),
    );
  }
}