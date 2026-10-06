import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nearby_chat_app/connection_screen.dart';
import 'package:nearby_chat_app/connection_service.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/main.dart' as chat;
import 'package:nearby_chat_app/game_screen.dart';
import 'package:nearby_chat_app/walkie_talkie_screen.dart';
import 'package:nearby_chat_app/ludo/ludo_screen.dart';

class FeatureSelectionScreen extends StatefulWidget {
  const FeatureSelectionScreen({super.key});

  @override
  State<FeatureSelectionScreen> createState() => _FeatureSelectionScreenState();
}

class _FeatureSelectionScreenState extends State<FeatureSelectionScreen> {
  final ConnectionService _conn = ConnectionService.instance;
  late LinkSnapshot _snap;
  StreamSubscription<LinkSnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _snap = _conn.snapshot;
    _sub = _conn.snapshotStream.listen((s) {
      _snap = s;
      if (mounted) setState(() {});
      if (!s.isConnected) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ConnectionScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: AppTokens.background,
        elevation: 0,
        title: Text('Nearby Connect', style: AppTokens.appBarTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off_rounded, color: AppTokens.text),
            onPressed: () => _conn.disconnect(),
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: SafeArea(
        child: _snap.isConnected
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppTokens.xxl + 8),
                    Text('Connected to ${_snap.connectedEndpointName ?? 'peer'}', style: AppTokens.muted(15)),
                    const SizedBox(height: AppTokens.xl),
                    const Text('Choose a feature', style: AppTokens.display),
                    const SizedBox(height: AppTokens.xxl + 8),
                    _FeatureCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Nearby Chat',
                      subtitle: 'Send messages to nearby devices',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const chat.ChatHomePage()),
                      ),
                    ),
                    const SizedBox(height: AppTokens.md),
                    _FeatureCard(
                      icon: Icons.settings_input_antenna_rounded,
                      title: 'Walkie Talkie',
                      subtitle: 'Push-to-talk voice communication',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalkieTalkieScreen()),
                      ),
                    ),
                    const SizedBox(height: AppTokens.md),
                    _FeatureCard(
                      icon: Icons.grid_on_rounded,
                      title: 'Tic-Tac-Toe',
                      subtitle: 'Play with a nearby friend',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GameScreen()),
                      ),
                    ),
                    const SizedBox(height: AppTokens.md),
                    _FeatureCard(
                      icon: Icons.casino_rounded,
                      title: 'Ludo',
                      subtitle: 'Classic board game, two players',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LudoScreen()),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: AppTokens.cardBorder,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTokens.tint,
                  borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                ),
                child: Icon(icon, color: AppTokens.accent, size: 26),
              ),
              const SizedBox(width: AppTokens.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTokens.h2),
                    const SizedBox(height: AppTokens.xs - 1),
                    Text(subtitle, style: AppTokens.muted(14)),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.sm + 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}