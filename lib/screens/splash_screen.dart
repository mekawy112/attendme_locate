import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
        splashIconSize: 200,
        animationDuration: const Duration(seconds: 4),
        splashTransition: SplashTransition.rotationTransition,
        splash: CircleAvatar(
          radius: 90,
          backgroundColor: Colors.white,
          backgroundImage:
              AssetImage('assets/images/Attendity.png'),
        ),
        nextScreen: const LoginScreen());
  }
}
