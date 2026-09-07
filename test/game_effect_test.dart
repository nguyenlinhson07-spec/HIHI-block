import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hihi_block/core/audio/game_audio.dart';
import 'package:hihi_block/core/haptics/game_haptics.dart';
import 'package:hihi_block/features/game/data/settings_store.dart';
import 'package:hihi_block/features/game/domain/models/block_cell.dart';
import 'package:hihi_block/features/game/domain/models/block_piece.dart';
import 'package:hihi_block/features/game/domain/models/game_board.dart';
import 'package:hihi_block/features/game/domain/models/game_effect.dart';
import 'package:hihi_block/features/game/logic/block_shapes.dart';
import 'package:hihi_block/features/game/logic/effect_dispatcher.dart';
import 'package:hihi_block/features/game/logic/game_controller.dart';
import 'package:hihi_block/features/game/logic/game_settings.dart';
import 'package:hihi_block/core/constants/game_constants.dart';

const int _size = GameConstants.boardSize;

BlockPiece _unit() => BlockShapes.single.toPiece(Colors.cyan);

GameBoard _boardWith(Iterable<BlockCell> cells) {
  GameBoard board = GameBoard.empty();
  for (final BlockCell c in cells) {
    board = board.placePiece(_unit(), c.row, c.column);
  }
  return board;
}

Iterable<BlockCell> _row(int row, {Set<int> gaps = const <int>{}}) sync* {
  for (int c = 0; c < _size; c++) {
    if (!gaps.contains(c)) yield BlockCell(row, c);
  }
}

Iterable<BlockCell> _column(int column, {Set<int> gaps = const <int>{}}) sync* {
  for (int r = 0; r < _size; r++) {
    if (!gaps.contains(r)) yield BlockCell(r, column);
  }
}

/// Two isolated holes per row and column: nothing but a single fits, and
/// filling one completes no line.
Set<BlockCell> _isolatedHoles() => <BlockCell>{
  for (int r = 0; r < _size; r++) ...<BlockCell>[
    BlockCell(r, (3 * r) % _size),
    BlockCell(r, (3 * r + 4) % _size),
  ],
};

Iterable<BlockCell> _allExcept(Set<BlockCell> free) sync* {
  for (int r = 0; r < _size; r++) {
    for (int c = 0; c < _size; c++) {
      if (!free.contains(BlockCell(r, c))) yield BlockCell(r, c);
    }
  }
}

/// Collects every effect a controller emits for the duration of [body].
Future<List<GameEffect>> capture(
  GameController controller,
  void Function() body,
) async {
  final List<GameEffect> seen = <GameEffect>[];
  final sub = controller.effects.listen(seen.add);
  body();
  // Let the broadcast stream deliver.
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return seen;
}

bool _drop(GameController c, int slot, int row, int column) {
  c.startDrag(slot, Offset.zero);
  c.updateDrag(Offset.zero, anchor: BlockCell(row, column));
  return c.endDrag();
}

List<GameEffectType> _types(List<GameEffect> effects) =>
    effects.map((GameEffect e) => e.type).toList();

int _countOf(List<GameEffect> effects, GameEffectType type) =>
    effects.where((GameEffect e) => e.type == type).length;

void main() {
  group('21. effect events', () {
    test('1. a valid placement emits exactly one placed effect', () async {
      final GameController c = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
      );
      final List<GameEffect> effects = await capture(
        c,
        () => _drop(c, 0, 2, 2),
      );

      expect(_countOf(effects, GameEffectType.placed), 1);
      expect(_countOf(effects, GameEffectType.invalid), 0);
      expect(_countOf(effects, GameEffectType.cleared), 0);

      final GameEffect placed = effects.firstWhere(
        (GameEffect e) => e.type == GameEffectType.placed,
      );
      expect(placed.cells.length, 2); // the domino
      expect(placed.scoreGained, 20);
      expect(placed.color, c.board.cellAt(2, 2).color);
      c.dispose();
    });

    test('2. an invalid release emits exactly one invalid effect', () async {
      final GameController c = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
      );
      final List<GameEffect> effects = await capture(c, () {
        c.startDrag(0, Offset.zero);
        c.updateDrag(Offset.zero, anchor: const BlockCell(0, 7));
        expect(c.endDrag(), isFalse);
      });

      expect(_countOf(effects, GameEffectType.invalid), 1);
      expect(_countOf(effects, GameEffectType.placed), 0);
      expect(_countOf(effects, GameEffectType.cleared), 0);
      expect(_countOf(effects, GameEffectType.gameOver), 0);
      c.dispose();
    });

    test('3. a clear emits a cleared effect carrying its cells', () async {
      final GameController c = GameController.withState(
        board: _boardWith(_row(3, gaps: <int>{7})),
        tray: <BlockPiece?>[_unit()],
      );
      final List<GameEffect> effects = await capture(
        c,
        () => _drop(c, 0, 3, 7),
      );

      expect(_countOf(effects, GameEffectType.cleared), 1);
      final GameEffect cleared = effects.firstWhere(
        (GameEffect e) => e.type == GameEffectType.cleared,
      );
      expect(cleared.cells.length, _size);
      expect(cleared.lineCount, 1);
      expect(cleared.scoreGained, 110);

      // Placed always comes before cleared, so presentation can order itself.
      expect(
        _types(effects).indexOf(GameEffectType.placed),
        lessThan(_types(effects).indexOf(GameEffectType.cleared)),
      );
      c.dispose();
    });

    test('4. a row+column clear lists the intersection once', () async {
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          ..._row(3, gaps: <int>{5}),
          ..._column(5, gaps: <int>{3}),
        }),
        tray: <BlockPiece?>[_unit()],
      );
      final List<GameEffect> effects = await capture(
        c,
        () => _drop(c, 0, 3, 5),
      );

      final GameEffect cleared = effects.firstWhere(
        (GameEffect e) => e.type == GameEffectType.cleared,
      );
      expect(cleared.lineCount, 2);
      // 8 + 8 minus the shared cell, and no repeats in the payload.
      expect(cleared.cells.length, _size + _size - 1);
      expect(cleared.cells.toSet().length, cleared.cells.length);
      expect(
        cleared.cells.where((BlockCell c) => c == const BlockCell(3, 5)).length,
        1,
      );
      // One cleared effect, not one per line.
      expect(_countOf(effects, GameEffectType.cleared), 1);
      c.dispose();
    });

    test('5. a streak of two emits a combo effect', () async {
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          ..._row(0, gaps: <int>{7}),
          ..._row(2, gaps: <int>{7}),
        }),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
      );

      final List<GameEffect> first = await capture(c, () => _drop(c, 0, 0, 7));
      expect(c.combo, 1);
      expect(
        _countOf(first, GameEffectType.combo),
        0,
        reason: 'the first clear of a streak is not a combo yet',
      );

      final List<GameEffect> second = await capture(c, () => _drop(c, 1, 2, 7));
      expect(c.combo, 2);
      expect(_countOf(second, GameEffectType.combo), 1);
      final GameEffect combo = second.firstWhere(
        (GameEffect e) => e.type == GameEffectType.combo,
      );
      expect(combo.combo, 2);
      c.dispose();
    });

    test(
      '6. a placement that clears nothing emits no clear or combo',
      () async {
        final GameController c = GameController.withState(
          board: GameBoard.empty(),
          tray: BlockShapes.sampleTray(),
        );
        final List<GameEffect> effects = await capture(
          c,
          () => _drop(c, 0, 4, 4),
        );

        expect(_countOf(effects, GameEffectType.placed), 1);
        expect(_countOf(effects, GameEffectType.cleared), 0);
        expect(_countOf(effects, GameEffectType.combo), 0);
        c.dispose();
      },
    );

    test('7. game over is emitted exactly once', () async {
      final GameController c = GameController.withState(
        board: _boardWith(_allExcept(_isolatedHoles())),
        tray: <BlockPiece?>[
          _unit(),
          BlockShapes.square2.toPiece(Colors.green),
          BlockShapes.line5H.toPiece(Colors.amber),
        ],
      );

      final List<GameEffect> effects = await capture(
        c,
        () => _drop(c, 0, 0, 0),
      );
      expect(c.isGameOver, isTrue);
      expect(_countOf(effects, GameEffectType.gameOver), 1);

      // Further drag attempts are refused and emit nothing at all.
      final List<GameEffect> after = await capture(c, () {
        expect(c.startDrag(1, Offset.zero), isFalse);
        expect(c.endDrag(), isFalse);
      });
      expect(after, isEmpty);
      c.dispose();
    });

    test('16. play again does not replay the game over effect', () async {
      final GameController c = GameController.withState(
        board: _boardWith(_allExcept(_isolatedHoles())),
        tray: <BlockPiece?>[
          _unit(),
          BlockShapes.square2.toPiece(Colors.green),
          BlockShapes.line5H.toPiece(Colors.amber),
        ],
      );
      _drop(c, 0, 0, 0);
      expect(c.isGameOver, isTrue);

      final List<GameEffect> effects = await capture(c, c.reset);
      expect(effects, isEmpty);
      expect(c.isGameOver, isFalse);
      c.dispose();
    });

    test('effect ids are unique and increasing', () async {
      final GameController c = GameController.withState(
        board: _boardWith(_row(0, gaps: <int>{7})),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
      );
      final List<GameEffect> effects = await capture(c, () {
        _drop(c, 0, 0, 7);
        _drop(c, 1, 4, 4);
      });

      final List<int> ids = effects.map((GameEffect e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      for (int i = 1; i < ids.length; i++) {
        expect(ids[i], greaterThan(ids[i - 1]));
      }
      c.dispose();
    });

    test('picking a block up emits one dragStarted, moves emit none', () async {
      final GameController c = GameController.withState(
        board: GameBoard.empty(),
        tray: BlockShapes.sampleTray(),
      );
      final List<GameEffect> effects = await capture(c, () {
        c.startDrag(0, Offset.zero);
        // Many pointer moves, including several preview changes.
        for (int i = 0; i < 20; i++) {
          c.updateDrag(Offset(i.toDouble(), 0), anchor: BlockCell(0, i % 6));
        }
      });

      expect(_countOf(effects, GameEffectType.dragStarted), 1);
      expect(effects.length, 1, reason: 'pointer moves must be silent');
      c.dispose();
    });
  });

  group('effects never change the game', () {
    test('17./18./19./20. re-reading effects changes nothing', () async {
      final GameController c = GameController.withState(
        board: _boardWith(<BlockCell>{
          ..._row(0, gaps: <int>{7}),
          ..._row(2, gaps: <int>{7}),
        }),
        tray: <BlockPiece?>[_unit(), _unit(), _unit()],
      );

      _drop(c, 0, 0, 7);
      _drop(c, 1, 2, 7);

      final int occupied = c.board.occupiedCount;
      final int score = c.score;
      final int combo = c.combo;
      final int best = c.bestScore;

      // Draining the stream again after the fact is inert: the effects are
      // one-shot, so nothing is replayed and nothing is recomputed.
      final List<GameEffect> late = await capture(c, () {});
      expect(late, isEmpty);

      expect(c.board.occupiedCount, occupied);
      expect(c.score, score);
      expect(c.combo, combo);
      expect(c.bestScore, best);
      c.dispose();
    });

    test(
      '17. the board is already final when the clear effect fires',
      () async {
        final GameController c = GameController.withState(
          board: _boardWith(_row(3, gaps: <int>{7})),
          tray: <BlockPiece?>[_unit()],
        );

        int? occupiedAtEffectTime;
        final sub = c.effects.listen((GameEffect e) {
          if (e.type == GameEffectType.cleared) {
            occupiedAtEffectTime = c.board.occupiedCount;
          }
        });
        _drop(c, 0, 3, 7);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        // The row is gone before presentation ever hears about it, and stays
        // gone afterwards — the animation is a ghost, not a pending edit.
        expect(occupiedAtEffectTime, 0);
        expect(c.board.occupiedCount, 0);
        c.dispose();
      },
    );
  });

  group('9.-12. dispatcher honours the settings', () {
    late RecordingGameAudio audio;
    late RecordingGameHaptics haptics;

    EffectDispatcher build({bool sound = true, bool vibration = true}) {
      audio = RecordingGameAudio();
      haptics = RecordingGameHaptics();
      return EffectDispatcher(
        audio: audio,
        haptics: haptics,
        settings:
            GameSettings(
                store: InMemorySettingsStore(
                  sound: sound,
                  vibration: vibration,
                ),
              )
              ..setSoundEnabled(sound)
              ..setVibrationEnabled(vibration),
      );
    }

    GameEffect effect(GameEffectType type) =>
        GameEffect(id: 1, type: type, lineCount: 1, combo: 2);

    test('10. sound on sends every event to the audio service', () {
      final EffectDispatcher d = build();
      for (final GameEffectType type in GameEffectType.values) {
        d.dispatch(effect(type));
      }
      expect(audio.played, <GameSound>[
        GameSound.place,
        GameSound.invalid,
        GameSound.clear,
        GameSound.combo,
        GameSound.gameOver,
      ], reason: 'dragStarted is deliberately silent');
    });

    test('9. sound off plays nothing at all', () {
      final EffectDispatcher d = build(sound: false);
      for (final GameEffectType type in GameEffectType.values) {
        d.dispatch(effect(type));
      }
      expect(audio.played, isEmpty);
      // Vibration is a separate switch and still fires.
      expect(haptics.impacts, isNotEmpty);
    });

    test('12. vibration on maps events to the right strength', () {
      final EffectDispatcher d = build();
      d.dispatch(effect(GameEffectType.placed));
      d.dispatch(effect(GameEffectType.cleared));
      d.dispatch(effect(GameEffectType.invalid));
      expect(haptics.impacts, <HapticStrength>[
        HapticStrength.light,
        HapticStrength.medium,
        HapticStrength.selection,
      ]);
    });

    test('11. vibration off fires no haptics', () {
      final EffectDispatcher d = build(vibration: false);
      for (final GameEffectType type in GameEffectType.values) {
        d.dispatch(effect(type));
      }
      expect(haptics.impacts, isEmpty);
      // Sound is a separate switch and still plays.
      expect(audio.played, isNotEmpty);
    });

    test('both off is completely silent', () {
      final EffectDispatcher d = build(sound: false, vibration: false);
      for (final GameEffectType type in GameEffectType.values) {
        d.dispatch(effect(type));
      }
      expect(audio.played, isEmpty);
      expect(haptics.impacts, isEmpty);
    });
  });
}
