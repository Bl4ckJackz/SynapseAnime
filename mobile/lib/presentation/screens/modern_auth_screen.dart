import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:anime_ai_player/presentation/widgets/auth/login_form.dart';
import 'package:anime_ai_player/presentation/widgets/auth/register_form.dart';

class ModernAuthScreen extends ConsumerStatefulWidget {
  const ModernAuthScreen({super.key});

  @override
  ConsumerState<ModernAuthScreen> createState() => _ModernAuthScreenState();
}

class _ModernAuthScreenState extends ConsumerState<ModernAuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    // Animation for Flip (0 to 1)
    // 0 = Login (Front), 1 = Register (Back)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  void _toggleAuthMode() {
    if (_isLogin) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Force a light theme for the forms inside the glass card to ensure contrast
    // against the semi-transparent white background (which works best with dark text).
    // OR: Use dark theme for forms and dark glass background.
    // The user said "non si leggono bene per colpa dei colori".
    // Let's use a Dark Glass Card (black opacity) and white text (Dark Theme).
    final darkTheme = ThemeData.dark().copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIconColor: Colors.white70,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium:
            TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          // Background - Dark Anime Theme
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2D3436), // Dark Grey
                    Color(0xFF000000), // Black
                    Color(0xFF2D3436), // Dark Grey
                  ],
                ),
              ),
            ),
          ),

          // Background Lottie (Subtle) - Removed to prevent 404s
          // Positioned.fill(child: ...),

          // Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Dynamic Mascot Animation (Rocket / Cute Robot)
                  SizedBox(
                    height: 350,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _isLogin
                                ? Lottie.asset(
                                    'assets/animations/rocket_launch.json',
                                    key: const ValueKey('rocket'),
                                    height: 320,
                                  )
                                : Transform(
                                    transform: Matrix4.identity()
                                      ..scale(-1.0, 1.0, 1.0),
                                    alignment: Alignment.center,
                                    child: Lottie.asset(
                                      'assets/animations/cute_robot.json',
                                      key: const ValueKey('robot'),
                                      height: 300,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Flip Card with Scale Effect
                  Theme(
                    data: darkTheme, // Enforce dark theme for legibility
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final double angle = _flipAnimation.value * pi;
                        final bool isFront = angle < pi / 2;
                        final double tilt = (angle - pi / 2).abs() -
                            pi / 2; // 0 at center, -pi/2 at ends
                        final double scale = 1.0 -
                            (sin(angle).abs() *
                                0.1); // Scale down slightly at 90 degrees

                        final matrix = Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // Perspective
                          ..rotateY(angle)
                          ..scale(scale); // Add depth scale

                        // If back side, we need to rotate it PI again so it's not mirrored
                        if (!isFront) {
                          matrix.rotateY(pi);
                        }

                        return Transform(
                          transform: matrix,
                          alignment: Alignment.center,
                          child: isFront
                              ? _buildGlassCard(
                                  LoginForm(
                                    key: const ValueKey('login'),
                                    onRegisterTap: _toggleAuthMode,
                                    onLoginSuccess: () {
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      // The LoginForm handles navigation, but we intercept visually
                                      // We might need to delay navigation inside LoginForm if possible
                                      // or listen to provider.
                                      // For now, assuming LoginForm calls this callback just before success logic.
                                    },
                                  ),
                                )
                              : _buildGlassCard(
                                  RegisterForm(
                                    key: const ValueKey('register'),
                                    onLoginTap: _toggleAuthMode,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),

          // Welcome Loader Overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black, // Full screen opaque
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/animations/nuovo_welcome.json',
                        width: 300,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                      const Text("Benvenuto...",
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(
                0.4), // Darker glass for better contrast with white text
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
