import 'package:flutter/material.dart';

/// Colour palette for Hi Hi Block: deep purple/indigo background with
/// bright, high-contrast blocks.
class AppColors {
  const AppColors._();

  static const Color backgroundTop = Color(0xFF3A2A7A);
  static const Color backgroundBottom = Color(0xFF140F2E);

  static const Color boardBackground = Color(0xFF241A52);
  static const Color boardBorder = Color(0x33FFFFFF);
  static const Color emptyCell = Color(0xFF322663);

  /// Top edge of an empty cell — see [emptyCell]; the pair gives the grid a
  /// touch of depth instead of reading as one flat slab.
  static const Color emptyCellTop = Color(0xFF3B2E75);

  static const Color trayBackground = Color(0x1AFFFFFF);
  /// Marker left in a tray slot whose block has been played.
  static const Color traySlotEmpty = Color(0x14FFFFFF);

  /// Board highlight shown under a droppable block.
  static const Color previewValid = Color(0x66FFFFFF);
  static const Color previewValidBorder = Color(0xCCFFFFFF);

  /// Board highlight shown when the block cannot be dropped.
  static const Color previewInvalid = Color(0x55FF5C5C);

  /// Tint of a dragged block that cannot be dropped where it is.
  static const Color blockRejected = Color(0xFFB0567A);
  static const Color previewInvalidBorder = Color(0xAAFF5C5C);

  static const Color primary = Color(0xFF6C4FD6);
  static const Color accent = Color(0xFF4FD1FF);
  static const Color gold = Color(0xFFFFD166);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSoft = Color(0xFFB9AEE4);

  /// Bright fill colours used for the block pieces.
  static const List<Color> blockPalette = <Color>[
    Color(0xFF4FD1FF), // cyan
    Color(0xFFFF6B9D), // pink
    Color(0xFF7EE787), // green
    Color(0xFFFFD166), // gold
    Color(0xFFB18CFF), // violet
    Color(0xFFFF8A5C), // orange
  ];
}
