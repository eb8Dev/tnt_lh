import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/core/brand.dart';

/// Each store's look. A screen about one store (its bag, say) uses that
/// store's theme even while the other store is being browsed.
final ThemeData teasNTreesTheme = ThemeData(
  // Sheets keep a readable width on tablets instead of spanning the screen.
  bottomSheetTheme: const BottomSheetThemeData(
    constraints: BoxConstraints(maxWidth: 640),
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFFCFBF4),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF57733C), // Dark Green
    primary: const Color(0xFF57733C),
    onPrimary: const Color(0xFFF2F2F2),
    secondary: const Color(0xFFA5BF45),
    onSecondary: Colors.black,
    tertiary: const Color(0xFF8FA63F),
    onTertiary: Colors.black,
    surface: const Color(0xFFFCFBF4),
    onSurface: Colors.black,
  ),
  textTheme: GoogleFonts.poppinsTextTheme().copyWith(
    displayLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    displayMedium: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    displaySmall: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    headlineMedium: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    headlineSmall: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    titleLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
  ),
);

final ThemeData littleHTheme = ThemeData(
  // Sheets keep a readable width on tablets instead of spanning the screen.
  bottomSheetTheme: const BottomSheetThemeData(
    constraints: BoxConstraints(maxWidth: 640),
  ),
  useMaterial3: true,
  // Colours from the Cream N Crust logo; see Brands.
  scaffoldBackgroundColor: Brands.bakeryCream,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Brands.bakeryColor,
    primary: Brands.bakeryColor,
    onPrimary: Colors.white,
    secondary: Brands.bakeryChocolate,
    onSecondary: Colors.white,
    tertiary: Brands.bakeryIcing,
    onTertiary: Brands.bakeryChocolate,
    primaryContainer: Brands.bakeryIcingLight,
    onPrimaryContainer: Brands.bakeryChocolate,
    surface: Brands.bakeryCream,
    onSurface: Colors.black,
  ),
  textTheme: GoogleFonts.poppinsTextTheme().copyWith(
    displayLarge: GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.bold,
      color: Brands.bakeryChocolate,
    ),
    displayMedium: GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.bold,
      color: Brands.bakeryChocolate,
    ),
    displaySmall: GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.bold,
      color: Brands.bakeryChocolate,
    ),
    headlineLarge: GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.bold,
      color: Brands.bakeryChocolate,
    ),
    headlineMedium: GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.bold,
      color: Brands.bakeryChocolate,
    ),
    headlineSmall: GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.bold,
      color: Brands.bakeryChocolate,
    ),
    titleLarge: GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.w600,
      color: Brands.bakeryChocolate,
    ),
  ),
);

ThemeData themeFor(String? store) =>
    Brands.isBakery(store) ? littleHTheme : teasNTreesTheme;
