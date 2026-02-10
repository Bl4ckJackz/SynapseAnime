import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:anime_ai_player/presentation/widgets/auth/login_form.dart';
import 'package:anime_ai_player/presentation/widgets/auth/register_form.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final int initialPage;
  const AuthScreen({super.key, this.initialPage = 4});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  late bool _isLogin;
  bool _isLoading = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  AnimationController? _welcomeController;

  // Wave animation controller
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialPage != 5;

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: _isLogin ? 0.0 : 1.0,
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    // Smooth flowing wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  void _onWelcomeAnimationComplete() {
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
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
    _welcomeController?.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pure black background
          Positioned.fill(
            child: Container(color: Colors.black),
          ),

          // Animated flowing waves (Gemini style)
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _GeminiWavePainter(
                  animationValue: _waveController.value,
                ),
              );
            },
          ),

          // Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo
                  _buildLogo(),

                  const SizedBox(height: 48),

                  // Flip Card
                  AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final double angle = _flipAnimation.value * pi;
                      final bool isFront = angle < pi / 2;
                      final double scale = 1.0 - (sin(angle).abs() * 0.1);

                      final matrix = Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle)
                        ..scale(scale);

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
                ],
              ),
            ),
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: Colors.white.withOpacity(0.6)),
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
                color: Colors.black,
                child: Center(
                  child: Lottie.asset(
                    'assets/animations/nuovo_welcome.json',
                    width: 550,
                    fit: BoxFit.contain,
                    repeat: false,
                    controller: _welcomeController,
                    onLoaded: (composition) {
                      setState(() {
                        _welcomeController = AnimationController(
                          vsync: this,
                          duration: composition.duration,
                        );
                        _welcomeController!.addStatusListener((status) {
                          if (status == AnimationStatus.completed) {
                            _onWelcomeAnimationComplete();
                          }
                        });
                        _welcomeController!.forward();
                      });
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Play icon with subtle glow
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: 44,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'SynapseAnime',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to continue',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Gemini-style flowing wave painter
class _GeminiWavePainter extends CustomPainter {
  final double animationValue;

  _GeminiWavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // We map the 0..1 animation value to 0..2*pi
    final t = animationValue * 2 * pi;

    // Draw multiple flowing wave lines
    for (int i = 0; i < 3; i++) {
      _drawFlowingWave(
        canvas,
        size,
        waveIndex: i,
        time: t,
      );
    }
  }

  void _drawFlowingWave(Canvas canvas, Size size,
      {required int waveIndex, required double time}) {
    final path = Path();

    // Base vertical position
    final baseY = size.height * (0.4 + waveIndex * 0.15);

    // Amplitude of the wave
    final amplitude = 40.0 + waveIndex * 10;

    // Frequency of the spatial wave (how many peaks across screen)
    final spatialFreq = 0.005;

    // Phase offset to separate the lines
    final phaseOffset = waveIndex * 2.0;

    path.moveTo(-50, baseY);

    for (double x = -50; x <= size.width + 50; x += 5) {
      final progress = x / size.width;

      // To make it loop seamlessly, the time-dependent term must be periodic over 2*pi.
      // sin(A + time) is periodic over 2*pi.
      // We combine spatial variation (x) with temporal variation (time).

      // Wave 1: Main flowing component
      // sin(x * freq + time) -> moves left
      final w1 = sin(x * spatialFreq + time + phaseOffset);

      // Wave 2: Secondary component with different speed/freq
      // To loop perfectly, the time multiplier must be an integer (1, 2, 3...)
      // sin(x * freq * 1.5 + time * 2) -> creates variation
      final w2 = sin(x * spatialFreq * 1.5 + time * 2 + phaseOffset);

      // Wave 3: Third component
      final w3 = cos(x * spatialFreq * 0.5 - time + phaseOffset);

      // Combine waves
      final combinedWave = (w1 * 0.5 + w2 * 0.3 + w3 * 0.2) * amplitude;

      // Envelope to fade edges gently
      final envelope = sin(progress * pi);

      final y = baseY + combinedWave * envelope;

      if (x == -50) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gradient styling
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + waveIndex * 0.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.05), // Taper off
          Colors.white.withOpacity(0),
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GeminiWavePainter oldDelegate) => true;
}
