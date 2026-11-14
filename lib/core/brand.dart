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

  // Cream N Crust, taken from its logo: the strawberry-pink iced cake, the
  // chocolate lettering, cream. The app used to paint the bakery in the
  // chocolate alone, which read as the old brown Little H.
  /// Buttons, selected states, prices. Deep enough for white text (5.3:1).
  static const Color bakeryColor = Color(0xFFC92A60);

  /// The wordmark's chocolate: headings and strong text.
  static const Color bakeryChocolate = Color(0xFF4A1D0A);

  /// The cake's icing, for tints, chips and highlights.
  static const Color bakeryIcing = Color(0xFFF9B4CB);
  static const Color bakeryIcingLight = Color(0xFFFCE4EC);
  static const Color bakeryCream = Color(0xFFFFF8F3);

  static const String cafeLogo = 'assets/images/teas_n_trees_no_bg.png';
  // Cut from the supplied artwork; swap for the SVG when it arrives.
  static const String bakeryLogo = 'assets/images/cream_n_crust_logo.png';

  static bool isBakery(String? key) => key?.toLowerCase().trim() == bakeryKey;

  static String name(String? key) => isBakery(key) ? bakeryName : cafeName;
  static Color color(String? key) => isBakery(key) ? bakeryColor : cafeColor;
  static String logo(String? key) => isBakery(key) ? bakeryLogo : cafeLogo;
}
