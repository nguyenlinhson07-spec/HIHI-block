import 'package:flutter/foundation.dart';

import '../../../../core/constants/game_constants.dart';
import 'block_cell.dart';
import 'block_piece.dart';
import 'board_cell.dart';
import 'line_clear_result.dart';
import 'placement_result.dart';

/// Immutable snapshot of the board state.
///
/// All placement rules live here, so the widget layer never has to reason
/// about bounds or occupancy — it only asks and renders the answer.
@immutable
class GameBoard {
  GameBoard({required List<List<BoardCell>> cells})
    : cells = List<List<BoardCell>>.unmodifiable(
        cells.map(List<BoardCell>.unmodifiable),
      );

  /// An empty [GameConstants.boardSize] x [GameConstants.boardSize] board.
  factory GameBoard.empty([int size = GameConstants.boardSize]) {
    return GameBoard(
      cells: List<List<BoardCell>>.generate(
        size,
        (int row) => List<BoardCell>.generate(
          size,
          (int column) => BoardCell(row: row, column: column),
        ),
      ),
    );
  }

  final List<List<BoardCell>> cells;

  int get size => cells.length;

  BoardCell cellAt(int row, int column) => cells[row][column];

  bool contains(int row, int column) =>
      row >= 0 && column >= 0 && row < size && column < size;

  bool isOccupied(int row, int column) =>
      contains(row, column) && cells[row][column].occupied;

  /// Maps [piece] onto absolute board coordinates anchored at
  /// ([row], [column]) — the top-left corner of the piece's bounding box.
  List<BlockCell> cellsFor(BlockPiece piece, int row, int column) => piece.cells
      .map((BlockCell c) => BlockCell(row + c.row, column + c.column))
      .toList(growable: false);

  /// Tests whether [piece] can be anchored at ([row], [column]) and explains
  /// why not when it cannot.
  PlacementResult evaluate(BlockPiece piece, int row, int column) {
    final List<BlockCell> target = cellsFor(piece, row, column);

    // Bounds are checked before occupancy so an out-of-board drop is never
    // misreported as an overlap.
    for (final BlockCell c in target) {
      if (!contains(c.row, c.column)) {
        return PlacementResult(
          status: PlacementStatus.outOfBounds,
          cells: target,
        );
      }
    }
    for (final BlockCell c in target) {
      if (cells[c.row][c.column].occupied) {
        return PlacementResult(status: PlacementStatus.overlap, cells: target);
      }
    }
    return PlacementResult(status: PlacementStatus.valid, cells: target);
  }

  /// Whether [piece] fits when anchored at ([row], [column]).
  bool canPlace(BlockPiece piece, int row, int column) =>
      evaluate(piece, row, column).isValid;

  /// Returns a new board with [piece] written in at ([row], [column]).
  ///
  /// Throws a [StateError] if the placement is invalid — callers must check
  /// with [canPlace] (or [evaluate]) first.
  GameBoard placePiece(BlockPiece piece, int row, int column) {
    final PlacementResult result = evaluate(piece, row, column);
    if (!result.isValid) {
      throw StateError(
        'Cannot place ${piece.id} at ($row, $column): ${result.status.name}',
      );
    }

    final List<List<BoardCell>> next = cells
        .map((List<BoardCell> r) => List<BoardCell>.of(r))
        .toList();
    for (final BlockCell c in result.cells) {
      next[c.row][c.column] = next[c.row][c.column].copyWith(
        occupied: true,
        color: piece.color,
      );
    }
    return GameBoard(cells: next);
  }

  // --- Available moves ----------------------------------------------------

  /// Whether [piece] fits anywhere at all on this board.
  ///
  /// Only anchors where the piece's bounding box still fits inside the board
  /// are tried, so an oversized piece exits immediately.
  bool canPlaceAnywhere(BlockPiece piece) {
    final int lastRow = size - piece.rowCount;
    final int lastColumn = size - piece.columnCount;
    for (int row = 0; row <= lastRow; row++) {
      for (int column = 0; column <= lastColumn; column++) {
        if (canPlace(piece, row, column)) return true;
      }
    }
    return false;
  }

  /// Whether at least one piece still in [tray] has somewhere to go.
  ///
  /// Empty slots are skipped; an all-empty tray has no move by itself, which
  /// is why the controller refills before asking.
  bool hasAnyMove(List<BlockPiece?> tray) =>
      tray.any((BlockPiece? piece) => piece != null && canPlaceAnywhere(piece));

  // --- Line clearing ------------------------------------------------------

  /// Whether every cell in [row] is occupied.
  bool isRowFull(int row) => cells[row].every((BoardCell c) => c.occupied);

  /// Whether every cell in [column] is occupied.
  bool isColumnFull(int column) =>
      cells.every((List<BoardCell> row) => row[column].occupied);

  /// Scans the whole board for completed rows and columns.
  ///
  /// Rows and columns are scanned independently against the *same* snapshot,
  /// so a row that only becomes full because a column was cleared first can
  /// never be counted — and the cell where a full row crosses a full column
  /// lands in the result set exactly once.
  LineClearResult findFullLines() {
    final List<int> rows = <int>[];
    final List<int> columns = <int>[];
    for (int i = 0; i < size; i++) {
      if (isRowFull(i)) rows.add(i);
      if (isColumnFull(i)) columns.add(i);
    }
    if (rows.isEmpty && columns.isEmpty) return LineClearResult.none();

    final Set<BlockCell> target = <BlockCell>{};
    for (final int row in rows) {
      for (int column = 0; column < size; column++) {
        target.add(BlockCell(row, column));
      }
    }
    for (final int column in columns) {
      for (int row = 0; row < size; row++) {
        target.add(BlockCell(row, column));
      }
    }
    return LineClearResult(rows: rows, columns: columns, cells: target);
  }

  /// Returns a new board with every cell in [clear] emptied; all other cells
  /// keep their block and colour.
  GameBoard clearLines(LineClearResult clear) {
    if (clear.isEmpty) return this;

    final List<List<BoardCell>> next = cells
        .map((List<BoardCell> r) => List<BoardCell>.of(r))
        .toList();
    for (final BlockCell c in clear.cells) {
      next[c.row][c.column] = BoardCell(row: c.row, column: c.column);
    }
    return GameBoard(cells: next);
  }

  /// Number of occupied cells — handy for tests and later scoring.
  int get occupiedCount => cells
      .expand((List<BoardCell> r) => r)
      .where((BoardCell c) => c.occupied)
      .length;
}
