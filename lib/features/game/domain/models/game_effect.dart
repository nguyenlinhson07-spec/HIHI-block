import 'package:flutter/material.dart';

import 'block_cell.dart';

/// Something that just happened and is worth showing or hearing.
enum GameEffectType {
  /// A block was lifted out of the tray. Fires once per drag, never per move.
  dragStarted,

  /// A block was committed to the board.
  placed,

  /// A release that could not be placed.
  invalid,

  /// One or more lines were completed and removed.
  cleared,

  /// A clear that continued a streak (combo 2 or higher).
  combo,

  /// The board ran out of moves.
  gameOver,
}

/// A one-shot presentation event emitted by the controller.
///
/// Effects are pushed onto a stream rather than read off the controller's
/// state, so a widget rebuild can never replay a sound or a particle burst.
/// [id] is unique and increasing, which makes duplicates easy to spot.
@immutable
class GameEffect {
  GameEffect({
    required this.id,
    required this.type,
    List<BlockCell> cells = const <BlockCell>[],
    this.lineCount = 0,
    this.combo = 0,
    this.scoreGained = 0,
    this.color,
  }) : cells = List<BlockCell>.unmodifiable(cells);

  final int id;
  final GameEffectType type;

  /// For [GameEffectType.placed] the cells the block filled; for
  /// [GameEffectType.cleared] the cells that were emptied, intersections
  /// counted once.
  final List<BlockCell> cells;

  /// Rows + columns cleared by the placement this effect belongs to.
  final int lineCount;

  /// Combo streak after the placement.
  final int combo;

  /// Points the placement was worth.
  final int scoreGained;

  /// Colour of the block involved, when there is one.
  final Color? color;

  @override
  String toString() =>
      'GameEffect(#$id ${type.name}, ${cells.length} cells, '
      '$lineCount lines, combo $combo, +$scoreGained)';
}
