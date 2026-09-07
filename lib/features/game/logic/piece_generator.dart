import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/models/block_piece.dart';
import '../domain/models/game_board.dart';
import 'block_shapes.dart';

/// How likely each size class is, for one state of the board.
@immutable
class SizeWeights {
  const SizeWeights({
    required this.small,
    required this.medium,
    required this.large,
  });

  final int small;
  final int medium;
  final int large;

  int get total => small + medium + large;

  int weightOf(ShapeSize size) => switch (size) {
    ShapeSize.small => small,
    ShapeSize.medium => medium,
    ShapeSize.large => large,
  };
}

/// Deals the trays of three blocks the player picks from.
///
/// The random source is injected so tests can pin a seed and get the exact
/// same trays every run.
class PieceGenerator {
  PieceGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Upper bound on re-rolls when a candidate tray has no legal move.
  ///
  /// Bounded on purpose: if the board really is finished, the generator has
  /// to be allowed to hand back a dead tray so the game can end.
  static const int maxGenerateAttempts = 20;

  /// A board this full or fuller counts as crowded.
  static const double crowdedFillRatio = 0.6;

  /// Below this the board counts as open.
  static const double openFillRatio = 0.35;

  /// Open board: lean on medium shapes — line 3, small L, 2x2 — while still
  /// dealing the occasional big one.
  static const SizeWeights openWeights = SizeWeights(
    small: 25,
    medium: 50,
    large: 25,
  );

  /// Half-full board: everything is fair game.
  static const SizeWeights balancedWeights = SizeWeights(
    small: 33,
    medium: 34,
    large: 33,
  );

  /// Crowded board: small shapes get much likelier, but large ones never drop
  /// to zero — the game must still be able to end.
  static const SizeWeights crowdedWeights = SizeWeights(
    small: 55,
    medium: 32,
    large: 13,
  );

  /// Weights for a board that is [fillRatio] full.
  static SizeWeights weightsFor(double fillRatio) {
    if (fillRatio >= crowdedFillRatio) return crowdedWeights;
    if (fillRatio < openFillRatio) return openWeights;
    return balancedWeights;
  }

  /// Deals three blocks for [board].
  ///
  /// Candidate trays that leave the player with nothing to do are re-rolled up
  /// to [maxGenerateAttempts] times; the last candidate is returned either way,
  /// so a genuinely finished board still produces a tray and ends the game.
  ///
  /// [score] is accepted for future difficulty curves; the current weighting
  /// looks only at how full the board is.
  List<BlockPiece> generateTray(GameBoard board, int score) {
    final SizeWeights weights = weightsFor(fillRatioOf(board));

    List<BlockPiece> candidate = _rollTray(weights);
    for (int attempt = 1; attempt < maxGenerateAttempts; attempt++) {
      if (board.hasAnyMove(candidate)) return candidate;
      candidate = _rollTray(weights);
    }
    return candidate;
  }

  /// Fraction of the board that is occupied, 0..1.
  static double fillRatioOf(GameBoard board) =>
      board.occupiedCount / (board.size * board.size);

  List<BlockPiece> _rollTray(SizeWeights weights) => List<BlockPiece>.generate(
    GameConstants.traySlotCount,
    (_) => _rollPiece(weights),
  );

  BlockPiece _rollPiece(SizeWeights weights) {
    final BlockShape shape = _rollShape(weights);
    final Color color =
        AppColors.blockPalette[_random.nextInt(AppColors.blockPalette.length)];
    return shape.toPiece(color);
  }

  /// Picks a size class by weight, then a shape uniformly inside it.
  ///
  /// Because the shape is uniform within its class, no single shape is ever
  /// guaranteed — a crowded board makes small shapes likelier, it does not
  /// hand out singles on demand.
  BlockShape _rollShape(SizeWeights weights) {
    int roll = _random.nextInt(weights.total);
    for (final ShapeSize size in ShapeSize.values) {
      roll -= weights.weightOf(size);
      if (roll < 0) {
        final List<BlockShape> options = BlockShapes.ofSize(size);
        return options[_random.nextInt(options.length)];
      }
    }
    // Unreachable: the weights always sum to `total`.
    return BlockShapes.single;
  }
}
