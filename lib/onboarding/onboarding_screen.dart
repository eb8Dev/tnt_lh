import 'dart:ui';
import 'package:flutter/material.dart';

class _OnboardData {
  final String title;
  final String description;
  final String image;
  final List<Color> gradient;

  const _OnboardData({
    required this.title,
    required this.description,
    required this.image,
    required this.gradient,
  });
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  const OnboardingScreen({super.key, required this.onGetStarted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  double _page = 0;

  List<_OnboardData> get _pages => [
    const _OnboardData(
      title: "Teas n Trees Cafe",
      description: "Fresh brews, calm vibes, and nature-inspired teas.",
      image: "assets/images/teas_n_trees_no_bg.png",
      gradient: [Color(0xFFFDFFDC), Color(0xFFEAF4C8)],
    ),
    const _OnboardData(
      title: "Cafe Experience",
      description: "A peaceful place to sip, relax, and reconnect.",
      image: "assets/images/teas_n_trees_no_bg.png",
      gradient: [Color(0xFFF6F9D4), Color(0xFFDCEFA2)],
    ),
    _OnboardData(
      title: "Little H Bakery",
      description: "Freshly baked happiness made with love.",
      image: "assets/images/little_h_logo_no_bg.png",
      gradient: [Theme.of(context).colorScheme.surface, const Color(0xFFF3D4C2)],
    ),
    const _OnboardData(
      title: "Sweet Moments",
      description: "Desserts that make every moment special.",
      image: "assets/images/little_h_logo_no_bg.png",
      gradient: [Color(0xFFF5D6C6), Color(0xFFF0BFAE)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() => _page = _pageController.page ?? 0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic Background
          ..._pages.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final opacity = (1 - (_page - index).abs()).clamp(0.0, 1.0);

            return Opacity(
              opacity: opacity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: data.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            );
          }),

          // Content
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            itemBuilder: (_, i) {
              final progress = (_page - i).abs();
              final scale = 1 - (progress * 0.1).clamp(0.0, 0.2);
              final opacity = 1 - (progress * 0.5).clamp(0.0, 0.6);

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          _pages[i].image,
                          height: size.height * 0.35,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 60),
                        Text(
                          _pages[i].title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _pages[i].description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Bottom Bar
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => _buildIndicator(index),
                  ),
                ),
                const SizedBox(height: 40),

                // Button
                if (_page.round() == _pages.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: widget.onGetStarted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Get Started",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(int index) {
    final progress = (1 - (_page - index).abs()).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: 8 + (16 * progress),
      decoration: BoxDecoration(
        color: index == _page.round() ? Colors.black : Colors.black26,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
