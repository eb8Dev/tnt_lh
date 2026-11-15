import 'package:flutter/material.dart';

/// What each store is called and looks like on screen.
///
/// The bakery was Little H and is now Cream N Crust. Only the public face
/// changed: the backend, the API paths and the stored data still key it as
/// `littleh`, so that string stays everywhere it's used as an identifier.
/// Anything a customer reads or sees should come from here instead.
class Brands {
  Brands._();

  static const String cafeKey = 'teasntrees';
  static const String bakeryKey = 'littleh';

  static const String cafeName = 'Teas N Trees';
  static const String bakeryName = 'Cream N Crust';

  static const Color cafeColor = Color(0xFF57733C);

  // Cream N Crust's brand colour, Rust #B7410E (from the client), with the
  // logo's chocolate for headings and warm rust tints. An earlier pass used
  // the cake's strawberry pink; the brand colour is rust.
  /// Buttons, selected states, prices. White text on it reads at 5.7:1.
  static const Color bakeryColor = Color(0xFFB7410E);
  /// The wordmark's chocolate: headings and strong text.
  static const Color bakeryChocolate = Color(0xFF4A1D0A);
  /// Warm tints of the rust, for chips and highlights.
  static const Color bakeryIcing = Color(0xFFF2C4AE);
  static const Color bakeryIcingLight = Color(0xFFFBEDE6);
  static const Color bakeryCream = Color(0xFFFFF8F3);

  static const String cafeLogo = 'assets/images/teas_n_trees_no_bg.png';
  // Cut from the supplied artwork; swap for the SVG when it arrives.
  static const String bakeryLogo = 'assets/images/cream_n_crust_logo.png';

  static bool isBakery(String? key) => key?.toLowerCase().trim() == bakeryKey;

  static String name(String? key) => isBakery(key) ? bakeryName : cafeName;
  static Color color(String? key) => isBakery(key) ? bakeryColor : cafeColor;
  static String logo(String? key) => isBakery(key) ? bakeryLogo : cafeLogo;
}
