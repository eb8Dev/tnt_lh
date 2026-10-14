import 'package:tnt_lh/core/responsive.dart';
import 'dart:ui';
import 'package:tnt_lh/core/brand.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      title: Brands.bakeryName,
      description:
          "An artisan bakery. Freshly baked happiness, made with love.",
      image: Brands.bakeryLogo,
      gradient: [Theme.of(context).colorScheme.surface, Color(0xFFF3D4C2)],
    ),
    _OnboardData(
      title: "Sweet Moments",
      description: "Desserts that make every moment special.",
      image: Brands.bakeryLogo,
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

    return CenteredPage(
      child: Scaffold(
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
                      padding: EdgeInsets.all(40.r),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            _pages[i].image,
                            height: size.height * 0.35,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: 60.h),
                          Text(
                            _pages[i].title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            _pages[i].description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.black54,
                              height: 1.5.h,
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
                  SizedBox(height: 40.h),

                  // Button
                  if (_page.round() == _pages.length - 1)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.w),
                      child: SizedBox(
                        width: double.infinity,
                        height: 60.h,
                        child: ElevatedButton(
                          onPressed: widget.onGetStarted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            "Get Started",
                            style: TextStyle(
                              fontSize: 18.sp,
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
                          duration: Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: Icon(
                        PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(int index) {
    final progress = (1 - (_page - index).abs()).clamp(0.0, 1.0);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      height: 8.h,
      width: 8.w + (16 * progress),
      decoration: BoxDecoration(
        color: index == _page.round() ? Colors.black : Colors.black26,
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
  }
}
