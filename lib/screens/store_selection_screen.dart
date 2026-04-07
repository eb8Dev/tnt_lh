import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/screens/bakery/bakery_home.dart';
import 'package:tnt_lh/screens/cafe/cafe_home.dart';

class StoreSelectionScreen extends ConsumerStatefulWidget {
  const StoreSelectionScreen({super.key});

  @override
  ConsumerState<StoreSelectionScreen> createState() =>
      _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends ConsumerState<StoreSelectionScreen> {
  int _selectedIndex = 0;

  final List<Map<String, String>> outlets = [
    {
      "name": "Teas N Trees",
      "subtitle": "Cafe & Roastery",
      "image": "assets/images/teas_n_trees_no_bg.png",
      "description":
          "Premium teas and artisanal coffee brewed to perfection in a zen atmosphere.",
      "cta": "Explore Cafe",
      "brand": "teasntrees",
    },
    {
      "name": "Little H",
      "subtitle": "Artisanal Bakery",
      "image": "assets/images/little_h_logo_no_bg.png",
      "description":
          "Handcrafted breads, pastries, and sweet treats baked fresh every morning.",
      "cta": "Explore Bakery",
      "brand": "littleh",
    },
  ];

  Future<void> _navigate() async {
    final brand = outlets[_selectedIndex]['brand']!;
    await ref.read(brandProvider.notifier).setBrand(brand);

    if (!mounted) return;

    if (_selectedIndex == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CafeHome()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BakeryHome()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome to",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "The House of Flavors",
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA9BCA4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                itemCount: outlets.length,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                controller: PageController(
                  viewportFraction: 0.85,
                  initialPage: 0,
                ),
                itemBuilder: (context, index) {
                  final outlet = outlets[index];
                  final isActive = _selectedIndex == index;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutQuint,
                    margin: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: isActive ? 20 : 40,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isActive ? 0.08 : 0.03,
                          ),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFA9BCA4).withValues(alpha: 0.3)
                            : Colors.grey.shade100,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Hero(
                              tag: outlet['brand']!,
                              child: Image.asset(
                                outlet['image']!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30.0,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  outlet['name']!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  outlet['subtitle']!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: const Color(0xFFA9BCA4),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  outlet['description']!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.black54,
                                    height: 1.6,
                                  ),
                                ),
                                const Spacer(),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 300),
                                  opacity: isActive ? 1.0 : 0.0,
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    margin: const EdgeInsets.only(bottom: 30),
                                    child: ElevatedButton(
                                      onPressed: isActive ? _navigate : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        outlet['cta']!,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(outlets.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _selectedIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _selectedIndex == index
                          ? const Color(0xFFA9BCA4)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
