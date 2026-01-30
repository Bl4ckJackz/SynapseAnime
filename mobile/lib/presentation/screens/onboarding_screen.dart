import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_swipe/liquid_swipe.dart';

/// Onboarding screen with Liquid Swipe animation
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final LiquidController _liquidController = LiquidController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Benvenuto in SynapseAnime',
      description:
          'La tua destinazione definitiva per guardare anime e leggere manga',
      icon: Icons.play_circle_filled,
      backgroundColor: const Color(0xFF6C5CE7),
    ),
    OnboardingPageData(
      title: 'Scopri Nuovi Anime',
      description:
          'Esplora migliaia di titoli, dai classici alle ultime uscite',
      icon: Icons.explore,
      backgroundColor: const Color(0xFF00B894),
    ),
    OnboardingPageData(
      title: 'Leggi Manga',
      description: 'Accedi alla libreria manga con capitoli sempre aggiornati',
      icon: Icons.menu_book,
      backgroundColor: const Color(0xFFE17055),
    ),
    OnboardingPageData(
      title: 'AI Chat Assistente',
      description: 'Chiedi consigli e raccomandazioni al nostro assistente AI',
      icon: Icons.smart_toy,
      backgroundColor: const Color(0xFF0984E3),
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          LiquidSwipe(
            pages: _pages.map((page) => _buildPage(page)).toList(),
            liquidController: _liquidController,
            onPageChangeCallback: (page) {
              setState(() => _currentPage = page);
            },
            waveType: WaveType.liquidReveal,
            enableSideReveal: true,
            slideIconWidget: _currentPage < _pages.length - 1
                ? const Icon(Icons.arrow_forward_ios, color: Colors.white)
                : null,
          ),

          // Skip button
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: const Text(
                'Salta',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          // Page indicators
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: _currentPage == index ? 1.0 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // Get Started button on last page
          if (_currentPage == _pages.length - 1)
            Positioned(
              bottom: 40,
              left: 40,
              right: 40,
              child: ElevatedButton(
                onPressed: _completeOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _pages[_currentPage].backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Inizia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPageData page) {
    return Container(
      color: page.backgroundColor,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            page.icon,
            size: 120,
            color: Colors.white,
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color backgroundColor;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.backgroundColor,
  });
}

/// Check if onboarding is complete
Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
}
