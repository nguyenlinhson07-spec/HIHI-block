/// Static gameplay + layout constants shared across the game feature.
class GameConstants {
  const GameConstants._();

  /// The board is always square: [boardSize] x [boardSize] cells.
  static const int boardSize = 8;

  /// Number of block pieces offered in the tray at once.
  static const int traySlotCount = 3;

  /// Gap between two board cells, in logical pixels.
  static const double cellGap = 4.0;

  /// Padding inside the board container, in logical pixels.
  static const double boardPadding = 8.0;

  /// Corner radius of a single board / block cell.
  static const double cellRadius = 6.0;

  /// Corner radius of the board container.
  static const double boardRadius = 18.0;

  /// Maximum width the playfield is allowed to take on wide screens.
  static const double maxContentWidth = 480.0;

  /// Horizontal padding around the playfield column.
  static const double screenHorizontalPadding = 16.0;

  /// Vertical padding at the top and bottom of the playfield column.
  static const double screenVerticalPadding = 12.0;

  /// The one spacing step the playfield column uses between its rows, so the
  /// gaps read as a rhythm rather than as three arbitrary numbers.
  static const double stackSpacing = 8.0;

  /// How far above the pointer the dragged block floats, in logical pixels.
  ///
  /// Without this the block would sit under the player's finger and hide the
  /// preview it is meant to reveal.
  static const double dragLift = 84.0;

  /// Opacity of the block that follows the pointer.
  static const double dragGhostOpacity = 0.92;

  /// The dragged block is drawn slightly smaller than a board cell so the
  /// preview highlight stays visible as a ring around each of its squares.
  static const double dragGhostScale = 0.82;

  /// Gap between cells inside a tray/ghost block preview.
  static const double pieceGap = 3.0;

  // --- Tray -----------------------------------------------------------------

  /// Height of the tray strip.
  ///
  /// Generous on purpose: the previous 108 left the blocks at well under half
  /// the size of a board cell, which made a piece appear to double in size the
  /// moment it was picked up. The extra height comes out of the empty band
  /// that used to sit between the board and the tray.
  static const double trayHeight = 132.0;

  /// Padding inside the tray strip.
  static const double trayPadding = 10.0;

  /// Corner radius of the tray strip.
  static const double trayRadius = 22.0;

  /// Breathing room reserved on either side of a piece inside its slot.
  static const double traySlotMargin = 10.0;

  /// Smallest bounding box a tray slot is sized for.
  ///
  /// Without a floor, a tray of 1x1 blocks would render each one enormous.
  static const int trayMinimumSpan = 3;

  /// Bounds on the tray cell size. The maximum is close to a board cell on a
  /// typical phone, so a block barely changes size when it is lifted.
  static const double trayMinCellSize = 8.0;
  static const double trayMaxCellSize = 32.0;
}
