// ============================================================
// marker_helper.dart
// ------------------------------------------------------------
// Shared helper to generate a minimal white location pin / geotag
// marker with a subtle soft glow around the pin.
// Clean, small, and anchored precisely at the pin tip (0.5, 1.0).
// ============================================================

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerHelper {
  /// Creates a clean, small, minimal white location pin with a restrained,
  /// subtle soft glow.
  ///
  /// Pin geometry:
  /// - Total canvas size: 56 x 68 (allows room for the soft glow)
  /// - Pinhead radius: ~14
  /// - Pin height: ~36
  /// - Soft glow: Restrained blur around the pinhead & tip (white / soft glow)
  /// - Anchor: (0.5, 0.8) relative to canvas so the tip points directly at the coordinates.
  static Future<BitmapDescriptor> createMinimalWhitePinMarker() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    const double width = 56.0;
    const double height = 68.0;

    // Pin parameters inside the canvas
    const double headRadius = 14.0;
    const Offset headCenter = Offset(width / 2, 22.0);
    const Offset tip = Offset(width / 2, 54.0);

    // 1. Ground contact shadow under the tip
    final groundShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(tip.dx, tip.dy + 2.0), width: 14, height: 5),
      groundShadowPaint,
    );

    // Build the clean pin path
    final pinPath = Path();
    pinPath.moveTo(tip.dx, tip.dy);
    // Left curve up to head
    pinPath.cubicTo(
      tip.dx - headRadius * 0.95,
      tip.dy - headRadius * 0.95,
      headCenter.dx - headRadius,
      headCenter.dy + headRadius * 0.4,
      headCenter.dx - headRadius,
      headCenter.dy,
    );
    // Top circle arc
    pinPath.arcTo(
      Rect.fromCircle(center: headCenter, radius: headRadius),
      math.pi,
      math.pi,
      false,
    );
    // Right curve down to tip
    pinPath.cubicTo(
      headCenter.dx + headRadius,
      headCenter.dy + headRadius * 0.4,
      tip.dx + headRadius * 0.95,
      tip.dy - headRadius * 0.95,
      tip.dx,
      tip.dy,
    );
    pinPath.close();

    // 2. Subtle soft glow around the pin (restrained, soft white with gentle blur)
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(pinPath, glowPaint);

    // 3. Crisp subtle outer edge / border so the white pin pops cleanly on any map background
    final edgeBorderPaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(pinPath, edgeBorderPaint);

    // 4. Main minimal white body
    final whiteBodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, whiteBodyPaint);

    // 5. Clean, subtle inner core dot
    final innerDotPaint = Paint()
      ..color = const Color(0xFF4A4468)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(headCenter, headRadius * 0.32, innerDotPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Offset anchor for the minimal white pin created by [createMinimalWhitePinMarker].
  /// Maps to the tip at (width / 2, 54.0) within a (56 x 68) canvas.
  static const Offset pinAnchor = Offset(0.5, 54.0 / 68.0);
}
