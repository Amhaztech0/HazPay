import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import 'verify_otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Send magic link to email
  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();

    // Validate email
    if (email.isEmpty) {
      _showMessage('Please enter your email');
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Please enter a valid email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Send simple OTP code (not magic link) for manual entry
      await _authService.signInWithEmail(email, useMagicLink: false);
      
      if (mounted) {
        // Navigate to OTP verification screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyOTPScreen(
              email: email,
              isPhone: false,
            ),
          ),
        );
      }
    } catch (e) {
      _showMessage('Failed to send code: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Show snackbar message
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Image.asset(
                      'assets/images/owl_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // App name
                const Text(
                  'ZinChat',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.sm),
                
                // Tagline
                const Text(
                  'Zance da abokai',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Welcome text
                const Text(
                  'Welcome to ZinChat',
                  style: AppTextStyles.heading2,
                ),
                
                const SizedBox(height: AppSpacing.sm),
                
                const Text(
                  'Enter your email to get started',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Email input field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendMagicLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Info text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    'We\'ll send you a verification code to your email. No password needed!',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Note about phone auth
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.greyLight,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Phone authentication will be available soon!',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}