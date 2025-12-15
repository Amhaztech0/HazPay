import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

class VerifyOTPScreen extends StatefulWidget {
  final String email;
  final bool isPhone;

  const VerifyOTPScreen({
    super.key,
    required this.email,
    this.isPhone = false,
  });

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Verify OTP code
  Future<void> _verifyOTP({String? otpCode}) async {
    final otp = otpCode ?? _pinController.text.trim();

    debugPrint('=== OTP VERIFICATION DETAILS ===');
    debugPrint('Email: ${widget.email}');
    debugPrint('OTP entered: "$otp"');
    debugPrint('OTP length: ${otp.length}');
    debugPrint('Is phone: ${widget.isPhone}');

    if (otp.length != 8) {
      _showMessage('Please enter the complete 8-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isPhone) {
        await _authService.verifyPhoneOTP(widget.email, otp);
      } else {
        await _authService.verifyEmailOTP(widget.email, otp);
      }

      if (mounted) {
        // Navigate to home screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('OTP verification failed: $e');
      
      // Extract the actual error message
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.split('Exception:').last.trim();
      }
      
      _showMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Resend OTP
  Future<void> _resendOTP() async {
    try {
      await _authService.signInWithEmail(widget.email, useMagicLink: false);
      _showMessage('New code sent!');
    } catch (e) {
      _showMessage('Failed to resend code');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color.fromARGB(255, 65, 57, 212),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 45,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 22,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.divider),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Enter verification code',
                style: AppTextStyles.heading1,
              ),
              
              const SizedBox(height: AppSpacing.sm),
              
              // Subtitle
              Text(
                'We sent a code to ${widget.email}',
                style: AppTextStyles.bodyMedium,
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // OTP input boxes using Pinput
              Pinput(
                length: 8,
                controller: _pinController,
                focusNode: _focusNode,
                autofocus: true,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: const Color.fromARGB(255, 56, 46, 194), width: 2),
                  ),
                ),
                submittedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    color: AppColors.background,
                  ),
                ),
                errorPinTheme: defaultPinTheme.copyBorderWith(
                  border: Border.all(color: Colors.redAccent),
                ),
                onCompleted: (pin) {
                  _verifyOTP(otpCode: pin);
                },
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // Verify button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _verifyOTP(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 29, 29, 186),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Resend code button
              Center(
                child: TextButton(
                  onPressed: _resendOTP,
                  child: const Text(
                    'Didn\'t receive code? Resend',
                    style: TextStyle(
                      color: Color.fromARGB(255, 49, 29, 201),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Help text
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
                        'Check your email inbox and spam folder for the verification code',
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
    );
  }
}
