import 'dart:ui';
import 'package:attend_me_locate/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theming/colors.dart';
import '../services/auth_services.dart';
import '../widgets/app_text_form_field.dart';
import 'doctor_dashboard.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      String email = _emailController.text.trim();
      String password = _passwordController.text;

      if (email.isEmpty) {
        throw Exception('Please enter your email');
      }
      if (!email.contains('@')) {
        throw Exception('Please enter a valid email address');
      }
      if (password.isEmpty) {
        throw Exception('Please enter your password');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }

      final userData = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (userData != null) {
        // Check the user's role and navigate accordingly
        if (userData['role'] == 'doctor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorDashboard(
                doctorData: userData,
              ),
            ),
          );
        } else {
          // Navigate to home screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                userData: userData,
              ),
            ),
          );
        }
      }
    } catch (e) {
      String errorMessage = e.toString();
      // Remove 'Exception: ' prefix from error message if present
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background SVG
          Positioned.fill(
            child: SvgPicture.asset(
              "assets/svgs/login_background.svg",
              fit: BoxFit.cover,
            ),
          ),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Text(
                    "Attendity",
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      color: ColorsManager.whiteColor,
                      shadows: [
                        Shadow(
                          color: ColorsManager.whiteColor.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30.sp),
                  // Illustration Image
                  Container(
                    width: 180.w,
                    height: 180.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorsManager.whiteColor,
                      boxShadow: [
                        BoxShadow(
                          color: ColorsManager.whiteColor.withOpacity(0.3),
                          spreadRadius: 5,
                          blurRadius: 7,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/Attendity.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 30.sp),
                  // "Login to Your Account" Text
                  Text(
                    "LOGIN TO YOUR ACCOUNT",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 30.sp),

                  // Email Field
                  AppTextFormField(
                    label: 'University Account',
                    hintText: 'Enter your account',
                    controller: _emailController,
                    prefixIcon: const Icon(Icons.account_circle_outlined, color: ColorsManager.whiteColor),
                    style: const TextStyle(color: ColorsManager.whiteColor, fontSize: 16),
                    labelStyle: const TextStyle(color: ColorsManager.whiteColor, fontSize: 16),
                    hintStyle: const TextStyle(color: ColorsManager.whiteColor, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  AppTextFormField(
                    label: 'Password',
                    hintText: 'Please enter your password',
                    controller: _passwordController,
                    isObscureText: !_isPasswordVisible,
                    prefixIcon: const Icon(Icons.lock, color: ColorsManager.whiteColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        color: ColorsManager.whiteColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    style: const TextStyle(color: ColorsManager.whiteColor, fontSize: 16),
                    labelStyle: const TextStyle(color: ColorsManager.whiteColor, fontSize: 16),
                    hintStyle: const TextStyle(color: ColorsManager.whiteColor, fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(200.w, 55.h),
                      backgroundColor: ColorsManager.whiteColor,
                      foregroundColor: ColorsManager.darkBlueColor1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.sp),
                      ),
                      elevation: 5,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: ColorsManager.darkBlueColor1)
                        : Text(
                            "LOG IN",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: Text(
                      "Don't have an account? Sign Up",
                      style: TextStyle(
                        color: ColorsManager.whiteColor,
                        fontSize: 16,
                        shadows: [Shadow(color: ColorsManager.whiteColor.withOpacity(0.5), blurRadius: 2)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
