import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/games/ludo/ludo_board.dart';
import 'package:nearby_chat_app/games/ludo/ludo_dice.dart';
import 'package:nearby_chat_app/games/ludo/ludo_player_badge.dart';
import 'package:nearby_chat_app/games/ludo/ludo_service.dart';
import 'package:nearby_chat_app/games/ludo/ludo_state.dart';
import 'package:nearby_chat_app/games/ludo/ludo_victory_dialog.dart';
import 'package:nearby_chat_app/games/ludo/local_ludo_service.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key, this.localService});

  final LocalLudoService? localService;

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen>
    with SingleTickerProviderStateMixin {
  final LudoService _service = LudoService();
  final _rng = math.Random();

  LudoState _state = LudoState();
  int? _myPlayer;
  Timer? _autoPassTimer;
  Timer? _eventTimer;

  String? _event;
  int _lastDice = 0;
  double _cellSize = 0;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppTokens.motionPulse,
  );

  StreamSubscription<LudoState>? _stateSub;
  StreamSubscription<String>? _statusSub;

  bool get _isLocalMode => widget.localService != null;
  LocalLudoService get _local => widget.localService!;

  @override
  void initState() {
    super.initState();
    if (_isLocalMode) {
      _stateSub = _local.stateStream.listen((state) {
        if (!mounted) return;
        _detectEvents(_state, state);
        if (state.dice != null) _lastDice = state.dice!;
        setState(() => _state = state);
        _updatePulse();
      });
      _local.startGame();
    } else {
      _stateSub = _service.stateStream.listen((state) {
        if (!mounted) return;
        _detectEvents(_state, state);
        if (state.dice != null) _lastDice = state.dice!;
        setState(() => _state = state);
        _updatePulse();
      });
      _statusSub = _service.statusStream.listen((_) {
        if (!mounted) return;
        setState(() => _myPlayer = _service.myPlayer);
        _updatePulse();
      });
    }
  }

  bool get _connected => _isLocalMode ? true : _myPlayer != null;
  bool get _myTurn => _connected && _state.canAct(_humanPlayer);
  int get _humanPlayer => _isLocalMode ? _local.humanPlayer : (_myPlayer ?? 0);
  List<int> get _movable =>
      _connected ? _state.movablePieces(_humanPlayer) : const <int>[];

  void _rollDice() {
    if (!_myTurn || !_state.awaitingRoll) return;
    HapticFeedback.lightImpact();
    final roll = _rng.nextInt(6) + 1;
    if (_isLocalMode) {
      _local.rollDice(roll);
    } else {
      _service.rollDice(roll);
    }
    _scheduleAutoPassIfNeeded();
  }

  void _movePiece(int piece) {
    HapticFeedback.selectionClick();
    if (_isLocalMode) {
      _local.movePiece(piece);
    } else {
      _service.movePiece(piece);
    }
  }

  void _scheduleAutoPassIfNeeded() {
    _autoPassTimer?.cancel();
    _autoPassTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      if (_myTurn && _state.awaitingMove && _movable.isEmpty) {
        if (_isLocalMode) {
          _local.passTurn();
        } else {
          _service.passTurn();
        }
      }
    });
  }

  void _onBoardTap(Offset local) {
    if (!_connected || !_state.awaitingMove || !_myTurn || _cellSize == 0) {
      return;
    }
    final col = (local.dx / _cellSize).floor();
    final row = (local.dy / _cellSize).floor();
    if (row < 0 || row >= LudoBoard.size || col < 0 || col >= LudoBoard.size) {
      return;
    }

    for (final piece in _movable) {
      final pos = _state.pieces[_humanPlayer][piece];
      if (pos == LudoState.posBase) {
        final slot = LudoBoard.baseSlots[_humanPlayer][piece];
        if (slot[0] == row && slot[1] == col) {
          _movePiece(piece);
          return;
        }
        continue;
      }
      final cell = LudoBoard.cellOf(_humanPlayer, pos);
      if (cell != null && cell[0] == row && cell[1] == col) {
        _movePiece(piece);
        return;
      }
    }

    final dice = _state.dice;
    if (dice == null) return;
    for (final piece in _movable) {
      final pos = _state.pieces[_humanPlayer][piece];
      final rel = pos == LudoState.posBase ? 0 : pos + dice;
      final cell = LudoBoard.cellOf(_humanPlayer, rel);
      if (cell != null && cell[0] == row && cell[1] == col) {
        _movePiece(piece);
        return;
      }
    }
  }

  int _onTrack(List<int> pieces) =>
      pieces.where((p) => p >= 0 && p <= LudoBoard.trackLast).length;

  void _detectEvents(LudoState before, LudoState after) {
    if (after.version == 0 && before.version > 0) {
      _showEvent('New game');
      HapticFeedback.lightImpact();
      return;
    }

    if (after.isGameOver && !before.isGameOver) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (before.dice != null &&
        after.dice == null &&
        before.currentPlayer == after.currentPlayer) {
      final mover = before.currentPlayer;
      final iMoved = mover == _humanPlayer;
      final captured =
          _onTrack(after.pieces[1 - mover]) < _onTrack(before.pieces[1 - mover]);
      final finished = after.homeCount(mover) > before.homeCount(mover);
      if (captured) {
        _showEvent(iMoved ? 'You captured a piece — roll again'
                          : 'Opponent captured your piece');
        HapticFeedback.mediumImpact();
      } else if (finished) {
        _showEvent(iMoved ? 'Piece home — roll again'
                          : 'Opponent brought a piece home');
        HapticFeedback.lightImpact();
      }
      return;
    }

    if (before.dice == null &&
        after.dice == null &&
        before.currentPlayer != after.currentPlayer) {
      _showEvent(before.currentPlayer == _humanPlayer
          ? 'Three sixes — turn forfeited'
          : 'Opponent forfeited on three sixes');
      HapticFeedback.lightImpact();
    }
  }

  void _showEvent(String text) {
    _event = text;
    _eventTimer?.cancel();
    _eventTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _event = null);
    });
  }

  void _updatePulse() {
    final needs =
        _connected && _myTurn && _state.awaitingMove && _movable.isNotEmpty;
    if (needs && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!needs && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: AppTokens.background,
        elevation: 0,
        title: Text('Ludo', style: AppTokens.appBarTitle),
        centerTitle: true,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_rounded, color: AppTokens.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTokens.text, size: 22),
            tooltip: 'New game',
            onPressed: _isLocalMode
                ? () => _local.startGame()
                : () => _service.resetGame(),
          ),
        ],
      ),
      body: _connected ? _buildGameView() : _buildNotConnectedView(),
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTokens.tint,
                borderRadius: BorderRadius.circular(28),
              ),
              child:
                  Icon(Icons.casino_rounded, color: AppTokens.accent, size: 48),
            ),
            const SizedBox(height: AppTokens.md),
            Text('Ludo', style: AppTokens.h1),
            const SizedBox(height: AppTokens.sm),
            Text(
              'Not connected. Go back to establish connection.',
              style: AppTokens.muted(15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.lg),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Connection'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameView() {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.md),
      child: Column(
        children: [
          _buildStatusBar(),
          const SizedBox(height: AppTokens.md),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const pad = AppTokens.sm + 4.0;
                final side = math.max(
                  0.0,
                  math.min(constraints.maxWidth, constraints.maxHeight) -
                      pad * 2,
                );
                _cellSize = side / LudoBoard.size;
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(pad),
                    decoration: BoxDecoration(
                      color: AppTokens.surface,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusBoard),
                      border: AppTokens.cardBorder,
                      boxShadow: AppTokens.cardShadow,
                    ),
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _onBoardTap(d.localPosition),
                            child: AnimatedBuilder(
                              animation: _pulse,
                              builder: (context, _) => CustomPaint(
                                painter: LudoBoardPainter(
                                  _state,
                                  _humanPlayer,
                                  _movable.toSet(),
                                  _pulse.value,
                                ),
                              ),
                            ),
                          ),
                          if (_state.isGameOver) _buildWinnerOverlay(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppTokens.md),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    String title;
    String sub;
    if (_state.isGameOver) {
      title = _state.winner == _humanPlayer ? 'You won' : 'Game over';
      sub = 'Tap New Game to play again';
    } else if (_state.awaitingRoll) {
      if (_myTurn) {
        title = 'Your turn';
        sub = 'Roll the dice';
      } else {
        title = "Opponent's turn";
        sub = 'Waiting for them to roll…';
      }
    } else if (_state.awaitingMove) {
      if (_myTurn) {
        title = 'Your turn';
        sub = _movable.isEmpty
            ? 'No moves — passing…'
            : 'Tap a pulsing piece or its landing spot';
      } else {
        title = "Opponent's turn";
        sub = 'Waiting for them to move…';
      }
    } else {
      title = 'Ludo';
      sub = _isLocalMode ? 'vs Bots' : 'Connected';
    }
    if (_event != null && !_state.isGameOver) sub = _event!;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.sm + 4,
        horizontal: AppTokens.md,
      ),
      decoration: AppTokens.cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LudoPlayerBadge(
                  player: 0,
                  name: _isLocalMode
                      ? (_humanPlayer == 0 ? 'You' : 'Bot 1')
                      : (_myPlayer == 0 ? 'You' : 'Peer'),
                  isActive: !_state.isGameOver && _state.currentPlayer == 0,
                  isMe: _humanPlayer == 0,
                  homeCount: _state.homeCount(0),
                  dimmed: _state.isGameOver && _state.winner != 0,
                ),
              ),
              const SizedBox(width: AppTokens.sm),
              Expanded(
                child: LudoPlayerBadge(
                  player: 1,
                  name: _isLocalMode
                      ? (_humanPlayer == 1 ? 'You' : 'Bot 2')
                      : (_myPlayer == 1 ? 'You' : 'Peer'),
                  isActive: !_state.isGameOver && _state.currentPlayer == 1,
                  isMe: _humanPlayer == 1,
                  homeCount: _state.homeCount(1),
                  dimmed: _state.isGameOver && _state.winner != 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sm + 4),
          Text(title, style: AppTokens.h2),
          const SizedBox(height: 2),
          Text(
            sub,
            style: AppTokens.muted(13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final dice = _state.dice;
    final canRoll = _myTurn && _state.awaitingRoll;
    final activeColor = AppTokens.playerColor(_state.currentPlayer);

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.sm + 4,
        horizontal: AppTokens.md,
      ),
      decoration: AppTokens.cardDecoration(),
      child: Row(
        children: [
          LudoDice(
            value: dice ?? _lastDice,
            dimmed: dice == null,
            onRoll: _rollDice,
            canRoll: canRoll,
            activeColor: activeColor,
          ),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: _buildActionLabel(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionLabel() {
    String label;
    if (_state.isGameOver) {
      label = 'Game over';
    } else if (_state.awaitingRoll) {
      label = _myTurn ? 'Your roll' : 'Waiting…';
    } else if (_state.awaitingMove) {
      if (_myTurn && _movable.isEmpty) {
        label = 'No moves — passing…';
      } else if (_myTurn) {
        label = 'Tap a piece to move';
      } else {
        label = 'Waiting…';
      }
    } else {
      label = 'Ready';
    }

    return Container(
      height: 48,
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTokens.body.copyWith(
          fontWeight: FontWeight.w600,
          color: _myTurn ? AppTokens.accent : Colors.grey.shade400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildWinnerOverlay() {
    return LudoVictoryDialog(
      winner: _state.winner!,
      playerNames: _isLocalMode
          ? [
              _humanPlayer == 0 ? 'You' : 'Bot 1',
              _humanPlayer == 1 ? 'You' : 'Bot 2',
            ]
          : [
              _myPlayer == 0 ? 'You' : 'Peer',
              _myPlayer == 1 ? 'You' : 'Peer',
            ],
      homeCounts: [
        _state.homeCount(0),
        _state.homeCount(1),
      ],
      onPlayAgain: () {
        if (_isLocalMode) {
          _local.startGame();
        } else {
          _service.resetGame();
        }
      },
      onExit: () => Navigator.pop(context),
    );
  }

  @override
  void dispose() {
    _autoPassTimer?.cancel();
    _eventTimer?.cancel();
    _pulse.dispose();
    _stateSub?.cancel();
    _statusSub?.cancel();
    if (!_isLocalMode) _service.dispose();
    super.dispose();
  }
}
