import 'package:flutter/material.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/games/ludo/ludo_board.dart';

class LudoVictoryDialog extends StatelessWidget {
  const LudoVictoryDialog({
    super.key,
    required this.winner,
    required this.playerNames,
    required this.homeCounts,
    required this.onPlayAgain,
    required this.onExit,
  });

  final int winner;
  final List<String> playerNames;
  final List<int> homeCounts;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final color = AppTokens.playerColor(winner);

    return ColoredBox(
      color: AppTokens.text.withOpacity(0.35),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppTokens.motionSlow,
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.88 + 0.12 * t, child: child),
          ),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(AppTokens.lg),
            decoration: BoxDecoration(
              color: AppTokens.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.fromBorderSide(
                BorderSide(color: color.withOpacity(0.3), width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, color: color, size: 48),
                const SizedBox(height: AppTokens.md),
                Text('Victory!', style: AppTokens.h1),
                const SizedBox(height: AppTokens.xs),
                Text(
                  '${playerNames[winner]} wins!',
                  style: AppTokens.muted(14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTokens.md),
                ...List.generate(playerNames.length, (i) {
                  final isWinner = i == winner;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.xs),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTokens.playerColor(i),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.sm),
                        Expanded(
                          child: Text(
                            playerNames[i],
                            style: AppTokens.body.copyWith(
                              fontWeight: isWinner ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                        Text(
                          '${homeCounts[i]}/${LudoBoard.piecesPerPlayer}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppTokens.md),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: onPlayAgain,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTokens.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Play Again',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.sm),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onExit,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTokens.accentWith(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Exit to Menu',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTokens.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
