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
    if (!Responsive.isExpanded(context)) return child;
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

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F4E8), Color(0xFFF7EDE4)],
        ),
      ),
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
