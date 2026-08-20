import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const SplashScreen({super.key, required this.onGetStarted});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  Timer? _autoNavigateTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Start animation immediately
    _animController.forward();

    // Auto-advance after exactly 1 second (1000ms)
    _autoNavigateTimer = Timer(
      const Duration(milliseconds: 1000),
      widget.onGetStarted,
    );
  }

  @override
  void dispose() {
    _autoNavigateTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00157A), // Deep Brand Blue (matching logo background)
              Color(0xFF0028B8), // Royal Blue
              Color(0xFF0038D8), // Vibrant Accent Blue
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 38,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                  children: [
                    TextSpan(
                      text: 'Student',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: 'Hub',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF60A5FA), // Accent Soft Blue
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
