import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// google_fonts DOWNLOADS fonts from Google's CDN at runtime by default, so a
/// customer on a poor connection opened the app in the fallback typeface (and
/// paid for the data). Runtime fetching is now off and the .ttf files are
/// bundled under google_fonts/.
///
/// With fetching disabled, the only way Poppins can resolve is from those
/// bundled assets — so if these pass, the fonts are genuinely coming out of the
/// APK. Uses testWidgets so there's a real binding with an asset bundle.
void main() {
  testWidgets('Poppins and Playfair resolve from the bundled assets, with '
      'runtime fetching disabled', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    final poppins = GoogleFonts.poppins();
    final playfair = GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold);
    final bodyFont = GoogleFonts.poppinsTextTheme().bodyMedium?.fontFamily;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('cortado', style: poppins),
              Text('Teas n Trees', style: playfair),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(poppins.fontFamily, contains('Poppins'));
    expect(playfair.fontFamily, contains('PlayfairDisplay'));
    expect(bodyFont, contains('Poppins'));
  });
}
