import 'package:flutter/material.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/games/ludo/ludo_bot.dart';

class LudoBotSetupDialog extends StatefulWidget {
  const LudoBotSetupDialog({super.key});

  @override
  State<LudoBotSetupDialog> createState() => _LudoBotSetupDialogState();
}

class _LudoBotSetupDialogState extends State<LudoBotSetupDialog> {
  int _botCount = 1;
  BotDifficulty _difficulty = BotDifficulty.normal;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Play vs Bots', style: AppTokens.h1),
            const SizedBox(height: AppTokens.xs),
            Text(
              'Choose number of opponents',
              style: AppTokens.muted(14),
            ),
            const SizedBox(height: AppTokens.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1, 2, 3].map((n) {
                final selected = _botCount == n;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.xs),
                  child: GestureDetector(
                    onTap: () => setState(() => _botCount = n),
                    child: AnimatedContainer(
                      duration: AppTokens.motion,
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: selected ? AppTokens.accent : AppTokens.surface,
                        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: selected ? AppTokens.accent : AppTokens.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$n',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppTokens.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTokens.lg),
            Text('Difficulty', style: AppTokens.h2),
            const SizedBox(height: AppTokens.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: BotDifficulty.values.map((d) {
                final selected = _difficulty == d;
                final label = d.name[0].toUpperCase() + d.name.substring(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.xs),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _difficulty = d),
                    selectedColor: AppTokens.accent,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppTokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppTokens.surface,
                    side: BorderSide(
                      color: selected ? AppTokens.accent : AppTokens.border,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTokens.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context, (_botCount, _difficulty));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Start Game',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
