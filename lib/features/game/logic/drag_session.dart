import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../domain/models/block_cell.dart';
import '../domain/models/block_piece.dart';
import '../domain/models/placement_result.dart';

/// A drag in progress: which tray piece is in the air, where the pointer is,
/// and what would happen if the player let go right now.
@immutable
class DragSession {
  const DragSession({
    required this.slotIndex,
    required this.piece,
    required this.pointer,
    this.anchor,
    this.placement,
  });

  /// Tray slot the piece was picked up from.
  final int slotIndex;

  final BlockPiece piece;

  /// Current pointer position, in global coordinates.
  final Offset pointer;

  /// Board anchor the piece currently snaps to, or `null` when the piece is
  /// not over the board at all.
  final BlockCell? anchor;

  /// Placement outcome for [anchor]; `null` while off-board.
  final PlacementResult? placement;

  bool get isOverBoard => anchor != null;

  bool get canDrop => placement?.isValid ?? false;

  DragSession copyWith({
    Offset? pointer,
    BlockCell? anchor,
    PlacementResult? placement,
    bool clearAnchor = false,
  }) => DragSession(
    slotIndex: slotIndex,
    piece: piece,
    pointer: pointer ?? this.pointer,
    anchor: clearAnchor ? null : (anchor ?? this.anchor),
    placement: clearAnchor ? null : (placement ?? this.placement),
  );
}
