// ============================================================
// app_theme.dart
// ------------------------------------------------------------
// Central place for all colors, text styles, and reusable
// "neumorphic" (soft shadow) decorations used across the app.
// Keeping this in one file means the whole app's look can be
// changed by editing just this file.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Core purple / lavender palette
  static const Color background = Color(0xFFF3F0FA); // very light lavender
  static const Color primary = Color(0xFF8B7BD8);    // main purple
  static const Color primaryDark = Color(0xFF6A56C7); // darker purple (buttons)
  static const Color accent = Color(0xFFB9A9F0);      // soft lilac accent
  static const Color cardColor = Color(0xFFF3F0FA);   // same as bg for neumorphism
  static const Color textDark = Color(0xFF3A3556);
  static const Color textLight = Color(0xFF8E88A6);
  static const Color danger = Color(0xFFE85C5C);      // SOS red
  static const Color success = Color(0xFF6FCF97);
}

class AppTextStyles {
  // Using Poppins for headings, Inter for body text.
  static TextStyle heading = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static TextStyle subheading = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
  );

  static TextStyle button = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}

// ------------------------------------------------------------
// Neumorphism helper: creates the "soft UI" look using two
// shadows - one light (top-left) and one dark (bottom-right).
// This is what gives cards/buttons that soft, embossed feel.
// ------------------------------------------------------------
class AppDecorations {
  static BoxDecoration neumorphicCard({double radius = 24}) {
    return BoxDecoration(
      color: AppColors.cardColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Colors.white,
          offset: Offset(-6, -6),
          blurRadius: 16,
        ),
        BoxShadow(
          color: Color(0x33705C9E), // soft purple-grey shadow
          offset: Offset(6, 6),
          blurRadius: 16,
        ),
      ],
    );
  }

  // Pressed / inset look, used for selected nav items etc.
  static BoxDecoration neumorphicInset({double radius = 20}) {
    return BoxDecoration(
      color: AppColors.cardColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22705C9E),
          offset: Offset(2, 2),
          blurRadius: 6,
          spreadRadius: -2,
        ),
      ],
    );
  }

  static ThemeData themeData() {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: AppTextStyles.heading,
      ),
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    );
  }

  // Futuristic dark navy/purple-blue JSON styling for Google Maps
  static const String darkNavyMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#17192f"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#9ca4db"}]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#121424"}]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "administrative.country",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#4e4b85"}]
    },
    {
      "featureType": "administrative.land_parcel",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "administrative.neighborhood",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "landscape.man_made",
      "elementType": "geometry",
      "stylers": [{"color": "#1c1f38"}]
    },
    {
      "featureType": "landscape.natural",
      "elementType": "geometry",
      "stylers": [{"color": "#181a30"}]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [{"color": "#202340"}]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#282c52"}]
    },
    {
      "featureType": "road",
      "elementType": "labels.icon",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#8c94ce"}]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry",
      "stylers": [{"color": "#333968"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [{"color": "#4a458a"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#5c54a8"}]
    },
    {
      "featureType": "road.local",
      "elementType": "geometry",
      "stylers": [{"color": "#232749"}]
    },
    {
      "featureType": "transit",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#0d0f1f"}]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#515c8f"}]
    }
  ]
  ''';
}
