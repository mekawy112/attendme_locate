import 'dart:ui';
import 'package:attend_me_locate/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      final result = await _authService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (result['success']) {
        // Check the user's role and navigate accordingly
        if (result['user']['role'] == 'doctor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorDashboard(
                doctorData: result['user'],
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                userData: result['user'], // Pass the user data here
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
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
          // Background Image
          Positioned.fill(
            child: Image.asset(
              "assets/images/WhatsApp Image 2025-03-10 at 20.48.39_ce574561.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
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
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: ColorsManager.blueColor,
                    ),
                  ),
                  SizedBox(height: 20.sp),
                  // Illustration Image (Replace with your asset image)
                  Image.asset(
                    'assets/images/Attendity.png', // Add your image in assets
                    height: 160.h,
                  ),
                  SizedBox(height: 20.sp),
                  // "Login to Your Account" Text
                  Text(
                    "LOGIN TO YOUR ACCOUNT",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: ColorsManager.blueColor,
                    ),
                  ),
                  SizedBox(height: 20.sp),

                  // Email Field
                  AppTextFormField(
                    label: 'University Account',
                    hintText: 'Enter your account',
                    controller: _emailController,
                    prefixIcon: const Icon(Icons.account_circle_outlined,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  AppTextFormField(
                    label: 'Password',
                    hintText: 'Please enter your password',
                    controller: _passwordController,
                    prefixIcon: const Icon(Icons.lock, color: Colors.white),
                    suffixIcon:
                        const Icon(Icons.visibility, color: Colors.white),
                  ),

                  const SizedBox(height: 10),
                  // Remember Me Checkbox
                  Row(
                    children: [],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      fixedSize: Size(
                        164.w,
                        55.h,
                      ),
                      backgroundColor: Color(0XFF1C2D40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.sp),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 20),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "LOG IN",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      "Don't have an account? Sign Up",
                      style: TextStyle(color: Colors.white),
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
