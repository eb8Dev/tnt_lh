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

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _controller;
  double _page = 0;

  final List<_OnboardData> _pages = const [
    _OnboardData(
      title: "Teas n Trees Cafe",
      description: "Fresh brews, calm vibes, and nature-inspired teas.",
      image: "assets/images/teas_n_trees_no_bg.png",
      gradient: [Color(0xFFFDFFDC), Color(0xFFEAF4C8)],
    ),
    _OnboardData(
      title: "Cafe Experience",
      description: "A peaceful place to sip, relax, and reconnect.",
      image: "assets/images/teas_n_trees_no_bg.png",
      gradient: [Color(0xFFF6F9D4), Color(0xFFDCEFA2)],
    ),
    _OnboardData(
      title: "Little H Bakery",
      description: "Freshly baked happiness made with love.",
      image: "assets/images/little_h_logo_no_bg.png",
      gradient: [Color(0xFFF7E9DE), Color(0xFFF3D4C2)],
    ),
    _OnboardData(
      title: "Sweet Moments",
      description: "Desserts that make every moment special.",
      image: "assets/images/little_h_logo_no_bg.png",
      gradient: [Color(0xFFF5D6C6), Color(0xFFF0BFAE)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController()
      ..addListener(() {
        setState(() => _page = _controller.page ?? 0);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page.round() == _pages.length - 1) {
      widget.onGetStarted();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page.round() == _pages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, i) {
              final progress = (_page - i).abs();
              final scale = 1 - (progress * 0.1).clamp(0.0, 0.2);
              final opacity = 1 - (progress * 0.5).clamp(0.0, 0.6);

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: _OnboardingPage(
                    data: _pages[i],
                    pageOffset: _page - i,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 50,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: TextButton(
                  onPressed: widget.onGetStarted,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                  child: const Text(
                    "Skip",
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProgressBar(progress: (_page + 1) / _pages.length),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 6,
                    ),
                    child: Text(
                      isLast ? "Enter Experience" : "Continue",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardData data;
  final double pageOffset;

  const _OnboardingPage({required this.data, required this.pageOffset});

  @override
  Widget build(BuildContext context) {
    final imageTranslate = pageOffset * 40;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset(imageTranslate, 0),
                child: Image.asset(data.image, height: 230),
              ),
              const SizedBox(height: 60),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          width: MediaQuery.of(context).size.width * progress,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
