import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:tnt_lh/core/responsive.dart';

/// Sign-in screens on landscape tablets: the two stores on the left, the form
/// on the right at a comfortable width. Phones and portrait tablets get
/// [child] unchanged.
class AuthSplit extends StatelessWidget {
  const AuthSplit({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isTablet(context)) return child;

    // Portrait tablets: the screen as a card on the brand background, rather
    // than a phone-sized page with empty bands either side.
    if (!Responsive.isExpanded(context)) {
      return Container(
        decoration: const BoxDecoration(gradient: _brandGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 540,
                  maxHeight: 1080,
                ),
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  // The sign-in screens size their parts from the screen
                  // (MediaQuery); inside the card, the card is the screen.
                  child: LayoutBuilder(
                    builder: (context, box) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: box.biggest,
                        padding: EdgeInsets.zero,
                        viewPadding: EdgeInsets.zero,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        const Expanded(child: _BrandPanel()),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

const _brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF1F4E8), Color(0xFFF7EDE4)],
);

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _brandGradient),
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Image.asset(Brands.cafeLogo, height: 120)),
              const SizedBox(width: 32),
              Flexible(child: Image.asset(Brands.bakeryLogo, height: 120)),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            'BrewCrust',
            style: GoogleFonts.playfairDisplay(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tea and snacks from ${Brands.cafeName}, cakes and bakes from '
            '${Brands.bakeryName}, delivered in Guntur.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
