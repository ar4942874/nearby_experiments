import 'package:flutter/material.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/games/ludo/ludo_board.dart';

class LudoPlayerBadge extends StatelessWidget {
  const LudoPlayerBadge({
    super.key,
    required this.player,
    required this.name,
    required this.isActive,
    required this.isMe,
    required this.homeCount,
    this.dimmed = false,
  });

  final int player;
  final String name;
  final bool isActive;
  final bool isMe;
  final int homeCount;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = AppTokens.playerColor(player);
    final tint = AppTokens.playerTint(player);

    return AnimatedContainer(
      duration: AppTokens.motion,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.sm + 2, vertical: AppTokens.sm),
      decoration: BoxDecoration(
        color: isActive ? tint : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        border: Border.fromBorderSide(
          BorderSide(
            color: isActive ? color.withOpacity(0.5) : AppTokens.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withOpacity(0.25 + 0.15 * (dimmed ? 0 : 1)),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AnimatedOpacity(
        duration: AppTokens.motion,
        opacity: dimmed ? 0.6 : 1.0,
        child: Row(
          children: [
            _AvatarBadge(player: player, color: color, isActive: isActive),
            const SizedBox(width: AppTokens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTokens.body.copyWith(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: AppTokens.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isActive && !dimmed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTokens.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Waiting',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _ProgressBar(player: player, color: color, homeCount: homeCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.player,
    required this.color,
    required this.isActive,
  });

  final int player;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppTokens.motion,
      width: 36,
      height: 36,
      transform: Matrix4.identity()..scale(isActive ? 1.05 : 1.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            Color.lerp(color, Colors.white, 0.2)!,
            color,
          ],
        ),
        border: Border.fromBorderSide(
          BorderSide(
            color: isActive ? color : Colors.white,
            width: isActive ? 2.5 : 2,
          ),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '${player + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.player,
    required this.color,
    required this.homeCount,
  });

  final int player;
  final Color color;
  final int homeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: homeCount / LudoBoard.piecesPerPlayer,
                backgroundColor: AppTokens.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTokens.xs + 2),
        Text(
          '$homeCount/${LudoBoard.piecesPerPlayer}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
