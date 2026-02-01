import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anime_ai_player/presentation/widgets/auth/login_form.dart';
import 'package:anime_ai_player/presentation/widgets/auth/register_form.dart';

class AuthScreen extends StatefulWidget {
  final int initialPage;

  const AuthScreen({super.key, this.initialPage = 0});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late LiquidController _liquidController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _liquidController = LiquidController();
    _currentPage = widget.initialPage;

    // Jump to initial page after first frame if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPage > 0) {
        _liquidController.jumpToPage(page: widget.initialPage);
      }
    });
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildWelcomePage(),
      _buildFeaturePage(
        color: const Color(0xFF6C5CE7),
        title: 'Scopri Anime Illimitati',
        description:
            'Migliaia di episodi disponibili in streaming ad alta definizione. Il tuo portale per l\'animazione giapponese.',
        lottieUrl:
            'https://assets2.lottiefiles.com/packages/lf20_w51pcehl.json', // Example: Watching/TV
        icon: Icons.movie_filter_rounded,
      ),
      _buildFeaturePage(
        color: const Color(0xFF00B894),
        title: 'Leggi Manga Ovunque',
        description:
            'Una libreria immensa di manga sempre aggiornata. Leggi i tuoi capitoli preferiti in mobilità.',
        lottieUrl:
            'https://assets9.lottiefiles.com/packages/lf20_komemhol.json', // Example: Reading
        icon: Icons.menu_book_rounded,
      ),
      _buildFeaturePage(
        color: const Color(0xFFE17055),
        title: 'Assistente AI',
        description:
            'Il tuo assistente personale per scoprire nuovi titoli e ottenere raccomandazioni su misura.',
        lottieUrl:
            'https://assets4.lottiefiles.com/packages/lf20_snuuoxwc.json', // Example: Bot/Chat
        icon: Icons.smart_toy_rounded,
      ),
      _buildAuthPage(
        color: const Color(0xFF0984E3),
        child: LoginForm(
          onRegisterTap: () {
            // Animate to next page (Register)
            _liquidController.animateToPage(page: 5, duration: 600);
          },
        ),
      ),
      _buildAuthPage(
        color: const Color(
            0xFF6C5CE7), // Cycle back to a nice color or keep distinct
        child: RegisterForm(
          onLoginTap: () {
            // Animate back to Login
            _liquidController.animateToPage(page: 4, duration: 600);
          },
        ),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          LiquidSwipe(
            pages: pages,
            liquidController: _liquidController,
            onPageChangeCallback: (page) {
              setState(() => _currentPage = page);
              if (page >= 4) {
                _markOnboardingComplete();
              }
            },
            waveType: WaveType.liquidReveal,
            enableSideReveal: true,
            slideIconWidget: _currentPage < 4
                ? const Icon(Icons.arrow_back_ios, color: Colors.white)
                : null, // Only show swipe hint on tutorial pages
            initialPage: widget.initialPage,
            fullTransitionValue: 500,
            enableLoop: false,
            positionSlideIcon: 0.8,
          ),

          // Custom Navigation Controls for non-auth pages
          if (_currentPage < 4)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dots Indicator
                  Row(
                    children: List.generate(4, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withOpacity(_currentPage == index ? 1.0 : 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Skip / Next Buttons
                  TextButton(
                    onPressed: () {
                      _markOnboardingComplete();
                      _liquidController.animateToPage(page: 4, duration: 600);
                    },
                    child: const Text(
                      'Salta',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Container(
      color: Colors.black, // Dark background for premium feel
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Hero(
            tag: 'app_logo',
            child: Image.asset(
              'assets/images/logo.png',
              height: 150,
              width: 150,
            ),
          ),
          const SizedBox(height: 40),

          Text(
            'SynapseAnime',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'La tua esperienza anime definitiva.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w300,
                ),
          ),
          const SizedBox(height: 60),

          // Pulsing Lottie or arrow to encourage swipe
          Lottie.network(
            'https://assets10.lottiefiles.com/packages/lf20_6EFyFd.json', // Simple swipe hint or loader
            height: 80,
            errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 40),
          ),
          const Text(
            'Scorri per iniziare',
            style: TextStyle(color: Colors.white54),
          )
        ],
      ),
    );
  }

  Widget _buildFeaturePage({
    required Color color,
    required String title,
    required String description,
    required String lottieUrl,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Lottie.network(
              lottieUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(icon, size: 100, color: Colors.white),
            ),
          ),
          const SizedBox(height: 50),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPage({required Color color, required Widget child}) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Small logo at top of auth forms
              Image.asset('assets/images/logo.png', height: 80),
              const SizedBox(height: 30),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
