import 'dart:async';
import 'dart:math' as math;

import 'package:nearby_chat_app/games/ludo/ludo_bot.dart';
import 'package:nearby_chat_app/games/ludo/ludo_state.dart';

class LocalLudoService {
  LocalLudoService({required this.botCount, this.difficulty = BotDifficulty.normal})
      : _bot = LudoBot(difficulty: difficulty) {
    _state.reset();
  }

  final int botCount;
  final BotDifficulty difficulty;
  final LudoBot _bot;
  final math.Random _rng = math.Random();

  final LudoState _state = LudoState();
  final int _humanPlayer = 0;

  final StreamController<LudoState> _stateCtrl =
      StreamController<LudoState>.broadcast();
  Stream<LudoState> get stateStream => _stateCtrl.stream;

  LudoState get state => _state;
  int get humanPlayer => _humanPlayer;
  bool get isGameOver => _state.isGameOver;

  void startGame() {
    _state.reset();
    _emit();
    _maybeBotTurn();
  }

  void rollDice(int value) {
    if (_state.isGameOver) return;
    if (_state.currentPlayer != _humanPlayer) return;
    if (!_state.awaitingRoll) return;

    _state.roll(_humanPlayer, value);
    _emit();
    _afterAction();
  }

  void movePiece(int piece) {
    if (_state.isGameOver) return;
    if (_state.currentPlayer != _humanPlayer) return;
    if (!_state.awaitingMove) return;

    _state.move(_humanPlayer, piece, _state.dice!);
    _emit();
    _afterAction();
  }

  void passTurn() {
    if (_state.isGameOver) return;
    if (_state.currentPlayer != _humanPlayer) return;
    if (!_state.awaitingMove) return;

    _state.pass(_humanPlayer);
    _emit();
    _afterAction();
  }

  void _afterAction() {
    if (_state.isGameOver) return;
    if (_state.awaitingMove && _state.movablePieces(_state.currentPlayer).isEmpty) {
      Timer(const Duration(milliseconds: 800), () {
        if (_disposed) return;
        if (_state.awaitingMove &&
            _state.movablePieces(_state.currentPlayer).isEmpty) {
          _state.pass(_state.currentPlayer);
          _emit();
          _afterAction();
        }
      });
      return;
    }
    _maybeBotTurn();
  }

  void _maybeBotTurn() {
    if (_state.isGameOver) return;
    if (_state.currentPlayer == _humanPlayer) return;

    Timer(const Duration(milliseconds: 600), () {
      if (_disposed) return;
      if (_state.isGameOver) return;
      if (_state.currentPlayer == _humanPlayer) return;

      if (_state.awaitingRoll) {
        final roll = _rng.nextInt(6) + 1;
        _state.roll(_state.currentPlayer, roll);
        _emit();
        _afterAction();
      } else if (_state.awaitingMove) {
        final movable = _state.movablePieces(_state.currentPlayer);
        if (movable.isEmpty) {
          _state.pass(_state.currentPlayer);
          _emit();
          _afterAction();
        } else {
          final chosen = _bot.chooseMove(
            _state,
            _state.currentPlayer,
            _state.dice!,
          );
          if (chosen >= 0) {
            _state.move(_state.currentPlayer, chosen, _state.dice!);
            _emit();
            _afterAction();
          }
        }
      }
    });
  }

  bool _disposed = false;

  void _emit() {
    if (!_stateCtrl.isClosed) _stateCtrl.add(_state.copy());
  }

  void dispose() {
    _disposed = true;
    _stateCtrl.close();
  }
}
