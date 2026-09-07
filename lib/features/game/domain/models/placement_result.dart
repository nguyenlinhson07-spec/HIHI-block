import 'package:flutter/foundation.dart';

import 'block_cell.dart';

/// Why a placement was rejected (or that it was accepted).
enum PlacementStatus {
  /// The piece fits: every cell is inside the board and free.
  valid,

  /// At least one cell falls outside the board.
  outOfBounds,

  /// At least one cell lands on an already occupied board cell.
  overlap,
}

/// The outcome of testing a [BlockPiece] against a board anchor.
///
/// [cells] are the absolute board coordinates the piece would cover — they are
/// filled in even for an invalid result so the UI can draw a red preview.
@immutable
class PlacementResult {
  PlacementResult({required this.status, required List<BlockCell> cells})
    : cells = List<BlockCell>.unmodifiable(cells);

  final PlacementStatus status;
  final List<BlockCell> cells;

  bool get isValid => status == PlacementStatus.valid;

  @override
  String toString() => 'PlacementResult($status, ${cells.length} cells)';
}
