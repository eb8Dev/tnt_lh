import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Builds the live-tracking map's marker bitmaps.
///
/// Tracking used to draw three of Google's default teardrops — azure, green and
/// red — so the rider, the outlet and the customer's own doorstep were the same
/// shape in three colours. On a phone, mid-delivery, that's a legend you have to
/// memorise. These are three different things:
///
///  - the **rider**, a top-down scooter sprite turned to their heading;
///  - the **store**, a brand-coloured bubble with the cafe or bakery glyph;
///  - the **destination**, a house — it is the customer's own address, so a
///    photo of themselves would be meaningless here.
///
/// Kept in sync with the rider app's `lib/widgets/map_markers.dart`; if you
/// change the visual language, change both.
class MapMarkers {
  MapMarkers._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// The rider's bike, drawn bare on the map — no bubble, no ring, no halo.
  /// It's a top-down bike on a top-down map, the way Zomato and Swiggy draw it;
  /// wrapping it in a circle just turned it back into a pin.
  static Future<BitmapDescriptor> rider({double ratio = 3.0}) async {
    const key = 'rider';
    final cached = _cache[key];
    if (cached != null) return cached;

    final size = 56 * ratio;
    final bytes = await rootBundle.load('assets/images/rider_top_view.png');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetHeight: size.round(),
    );
    final sprite = (await codec.getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(
      sprite,
      Offset((size - sprite.width) / 2, (size - sprite.height) / 2),
      Paint()..filterQuality = FilterQuality.high,
    );

    final descriptor = await _finish(recorder, size, size, ratio);
    _cache[key] = descriptor;
    return descriptor;
  }

  static Future<BitmapDescriptor> store({
    required bool isBakery,
    double ratio = 3.0,
  }) async {
    final key = 'store_$isBakery';
    final cached = _cache[key];
    if (cached != null) return cached;

    final descriptor = await _bubble(
      ratio: ratio,
      accent: isBakery ? const Color(0xFFC0764F) : const Color(0xFF3E5138),
      builder: (canvas, centre, d) => _drawGlyph(
        canvas,
        centre,
        isBakery ? PhosphorIconsFill.bread : PhosphorIconsFill.coffee,
        d * 0.5,
        Colors.white,
      ),
    );
    _cache[key] = descriptor;
    return descriptor;
  }

  /// Where the order is going — the customer's own address.
  static Future<BitmapDescriptor> destination({
    required Color accent,
    double ratio = 3.0,
  }) async {
    final key = 'dest_${accent.toARGB32()}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final descriptor = await _bubble(
      ratio: ratio,
      accent: accent,
      builder: (canvas, centre, d) => _drawGlyph(
        canvas,
        centre,
        PhosphorIconsFill.house,
        d * 0.5,
        Colors.white,
      ),
    );
    _cache[key] = descriptor;
    return descriptor;
  }

  // ---------------------------------------------------------------- internals

  static Future<BitmapDescriptor> _bubble({
    required double ratio,
    required Color accent,
    required void Function(Canvas canvas, Offset centre, double diameter)
    builder,
  }) async {
    final w = 64 * ratio;
    final h = 78 * ratio;
    final diameter = 56 * ratio;
    final centre = Offset(w / 2, diameter / 2 + 3 * ratio);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      centre.translate(0, 2 * ratio),
      diameter / 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * ratio),
    );

    // Tail, so the bubble points at the coordinate rather than hovering.
    final tail = Path()
      ..moveTo(centre.dx - 7 * ratio, centre.dy + diameter * 0.42)
      ..lineTo(centre.dx, h - 2 * ratio)
      ..lineTo(centre.dx + 7 * ratio, centre.dy + diameter * 0.42)
      ..close();
    canvas.drawPath(tail, Paint()..color = Colors.white);

    canvas.drawCircle(centre, diameter / 2, Paint()..color = Colors.white);
    canvas.drawCircle(
      centre,
      diameter / 2 - 3 * ratio,
      Paint()..color = accent,
    );

    builder(canvas, centre, diameter - 6 * ratio);
    return _finish(recorder, w, h, ratio);
  }

  static void _drawGlyph(
    Canvas canvas,
    Offset centre,
    IconData icon,
    double size,
    Color color,
  ) {
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      )
      ..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  static Future<BitmapDescriptor> _finish(
    ui.PictureRecorder recorder,
    double w,
    double h,
    double ratio,
  ) async {
    final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    // Rendered at `ratio` for crispness — tell the plugin, or it draws a giant
    // 3x pin on a 3x screen.
    return BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: ratio,
    );
  }
}
