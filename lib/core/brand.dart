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
  // The chocolate brown of the Cream N Crust wordmark.
  static const Color bakeryColor = Color(0xFF63290C);

  static const String cafeLogo = 'assets/images/teas_n_trees_no_bg.png';
  // Cut from the supplied artwork; swap for the SVG when it arrives.
  static const String bakeryLogo = 'assets/images/cream_n_crust_logo.png';

  static bool isBakery(String? key) => key?.toLowerCase().trim() == bakeryKey;

  static String name(String? key) => isBakery(key) ? bakeryName : cafeName;
  static Color color(String? key) => isBakery(key) ? bakeryColor : cafeColor;
  static String logo(String? key) => isBakery(key) ? bakeryLogo : cafeLogo;
}
