import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/api_constants.dart';
import '../../utils/app_colors.dart';
import '../../routes/app_routes.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneOrEmailController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  @override
  void dispose() {
    _phoneOrEmailController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleReset(AuthService authService) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await authService.requestPasswordReset(
      _phoneOrEmailController.text.trim(),
    );

    if (success && mounted) {
      setState(() => _submitted = true);
      _showOTPDialog(authService);
    }
  }

  void _showOTPDialog(AuthService authService) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ResetOTPDialog(
        phoneOrEmail: _phoneOrEmailController.text.trim(),
        onSuccess: () {
          Navigator.pop(context); // Close OTP dialog
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Reset Password'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Consumer<AuthService>(
          builder: (context, authService, _) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_reset,
                            size: 40,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Forgot Password?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your phone number or email to reset your password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGray,
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Error Message
                      if (authService.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.errorRed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.errorRed,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authService.errorMessage ?? '',
                                  style: const TextStyle(
                                    color: AppColors.errorRed,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (authService.errorMessage != null)
                        const SizedBox(height: 16),
                      // Phone or Email Input
                      TextFormField(
                        controller: _phoneOrEmailController,
                        enabled: !authService.isLoading && !_submitted,
                        decoration: InputDecoration(
                          labelText: 'Phone Number or Email',
                          prefixIcon: const Icon(Icons.contacts),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: '+233201234567 or email@example.com',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Reset Button
                      ElevatedButton(
                        onPressed: (authService.isLoading || _submitted)
                            ? null
                            : () => _handleReset(authService),
                        child: authService.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Send Reset Code'),
                      ),
                      const SizedBox(height: 16),
                      // Back to Login
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.login);
                          },
                          child: const Text('Back to Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ResetOTPDialog extends StatefulWidget {
  final String phoneOrEmail;
  final VoidCallback onSuccess;

  const _ResetOTPDialog({
    required this.phoneOrEmail,
    required this.onSuccess,
  });

  @override
  State<_ResetOTPDialog> createState() => _ResetOTPDialogState();
}

class _ResetOTPDialogState extends State<_ResetOTPDialog> {
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  int _step = 1; // 1 = OTP, 2 = New Password

  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
  }

  void _handleVerifyOTP() {
    if (_otpController.text.isEmpty || _otpController.text.length != ApiConstants.otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid ${ApiConstants.otpLength}-digit OTP')),
      );
      return;
    }
    setState(() => _step = 2);
  }

  void _handleResetPassword() async {
    if (_newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final success = await _authService.confirmPasswordReset(
      phoneNumber: widget.phoneOrEmail,
      code: _otpController.text,
      newPassword: _newPasswordController.text,
      newPasswordConfirm: _confirmPasswordController.text,
    );

    if (success && mounted) {
      widget.onSuccess();
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _step == 1 ? const Text('Enter Code') : const Text('New Password'),
      content: Consumer<AuthService>(
        builder: (context, authService, _) {
          if (_step == 1) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter the ${ApiConstants.otpLength}-digit code sent to ${widget.phoneOrEmail}',
                  style: const TextStyle(color: AppColors.textGray),
                ),
                const SizedBox(height: 16),
                if (authService.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      authService.errorMessage!,
                      style: const TextStyle(color: AppColors.errorRed),
                    ),
                  ),
                TextField(
                  controller: _otpController,
                  enabled: !authService.isLoading,
                  maxLength: ApiConstants.otpLength,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: '0000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _newPasswordController,
                  enabled: !authService.isLoading,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  enabled: !authService.isLoading,
                  obscureText: _obscurePasswordConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasswordConfirm ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePasswordConfirm = !_obscurePasswordConfirm;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        Consumer<AuthService>(
          builder: (context, authService, _) {
            return ElevatedButton(
              onPressed: authService.isLoading
                  ? null
                  : (_step == 1 ? _handleVerifyOTP : _handleResetPassword),
              child: authService.isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_step == 1 ? 'Verify' : 'Reset Password'),
            );
          },
        ),
      ],
    );
  }
}
