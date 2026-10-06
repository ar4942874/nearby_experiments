import 'package:flutter/material.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/game_state.dart';
import 'package:nearby_chat_app/nearby_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final NearbyService _nearbyService = NearbyService();

  TicTacToeState _gameState = TicTacToeState();
  String? _myPlayer;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _nearbyService.gameStateStream.listen((state) {
      if (mounted) setState(() => _gameState = state);
    });
    _nearbyService.connectionStatusStream.listen((status) {
      if (mounted) setState(() => _myPlayer = _nearbyService.myPlayer);
    });
  }

  void _makeMove(int row, int col) {
    if (_myPlayer == null) {
      _showSnackBar("Not connected to any player!");
      return;
    }

    if (_gameState.currentPlayer != _myPlayer) {
      _showSnackBar("Wait for your turn!");
      return;
    }

    if (_gameState.makeMove(row, col)) {
      setState(() {});
      _nearbyService.sendMove(row, col);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _myPlayer != null;

    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: AppTokens.background,
        elevation: 0,
        title: Text(
          'Tic-Tac-Toe',
          style: TextStyle(
            color: AppTokens.text,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTokens.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: connected ? _buildGameView() : _buildNotConnectedView(),
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              child: Icon(Icons.grid_on_rounded, color: AppTokens.accent, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Tic-Tac-Toe',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTokens.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Not connected. Go back to establish connection.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Connection'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.accent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameView() {
    return Column(
      children: [
        _buildStatusBar(),
        Expanded(child: _buildGameBoard()),
        _buildControls(),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            'You are: $_myPlayer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTokens.text),
          ),
          const SizedBox(height: 8),
          if (_gameState.winner != null)
            Text(
              _gameState.winner == _myPlayer ? 'You Won!' : 'You Lost!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTokens.accent),
            )
          else if (_gameState.isDraw())
            Text(
              "It's a Draw!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
            )
          else
            Text(
              _gameState.currentPlayer == _myPlayer ? 'Your Turn' : "Opponent's Turn",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTokens.accent),
            ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              int row = index ~/ 3;
              int col = index % 3;
              String cellValue = _gameState.board[row][col];

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _makeMove(row, col),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cellValue.isEmpty ? Colors.grey.shade200 : AppTokens.accentWith(0.3),
                        width: 1.5,
                      ),
                      color: cellValue == "X"
                          ? AppTokens.tint
                          : cellValue == "O"
                              ? AppTokens.dangerWith(0.06)
                              : Colors.white,
                    ),
                    child: Center(
                      child: Text(
                        cellValue,
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          color: cellValue == "X" ? AppTokens.accent : AppTokens.danger,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _nearbyService.resetGame,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, color: AppTokens.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Reset Game',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nearbyService.dispose();
    super.dispose();
  }
}