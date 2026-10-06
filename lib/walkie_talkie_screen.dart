import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nearby_chat_app/connection_service.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/audio_service.dart';

class WalkieTalkieScreen extends StatefulWidget {
  const WalkieTalkieScreen({super.key});

  @override
  State<WalkieTalkieScreen> createState() => _WalkieTalkieScreenState();
}

class _WalkieTalkieScreenState extends State<WalkieTalkieScreen> {
  final ConnectionService _conn = ConnectionService.instance;
  final AudioService _audioService = AudioService();

  StreamSubscription<LinkSnapshot>? _snapSub;
  StreamSubscription<AppPayload>? _payloadSub;

  LinkSnapshot _snap = ConnectionService.instance.snapshot;
  bool _isTalking = false;

  @override
  void initState() {
    super.initState();
    _snapSub = _conn.snapshotStream.listen((s) {
      _snap = s;
      if (mounted) setState(() {});
    });
    _payloadSub = _conn.payloadStream.listen((p) {
      if (p.tag == ConnectionService.tagAudio) {
        _audioService.playAudioFromBytes(p.body);
      }
    });
  }

  @override
  void dispose() {
    _snapSub?.cancel();
    _payloadSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _snap.isConnected;
    final peerName = _snap.connectedEndpointName ?? 'peer';

    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: AppTokens.background,
        elevation: 0,
        title: Text(
          'Walkie Talkie',
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
      body: connected ? _buildWalkieTalkieView(peerName) : _buildNotConnectedView(),
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
              child: Icon(Icons.settings_input_antenna_rounded, color: AppTokens.accent, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Walkie Talkie',
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

  Widget _buildWalkieTalkieView(String peerName) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTokens.tint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.check_circle_rounded, color: AppTokens.accent, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                'Connected to $peerName',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.text,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTapDown: (_) => _onPushToTalk(),
          onTapUp: (_) => _onReleaseTalk(),
          onTapCancel: () => _onReleaseTalk(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isTalking ? AppTokens.danger : AppTokens.accent,
              boxShadow: [
                BoxShadow(
                  color: (_isTalking ? AppTokens.danger : AppTokens.accent).withValues(alpha: 0.3),
                  spreadRadius: _isTalking ? 20 : 8,
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isTalking ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 72,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  _isTalking ? 'TALKING' : 'PUSH TO TALK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Press and hold to talk\nRelease to send',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
          ),
        ),
      ],
    );
  }

  void _onPushToTalk() {
    if (!_snap.isConnected) return;
    setState(() => _isTalking = true);
    _audioService.startRecording();
  }

  void _onReleaseTalk() async {
    if (!_isTalking) return;
    setState(() => _isTalking = false);
    final audioPath = await _audioService.stopRecording();
    if (audioPath == null) return;

    try {
      final file = File(audioPath);
      final bytes = await file.readAsBytes();
      await _conn.sendAudio(Uint8List.fromList(bytes));
      await file.delete();
    } catch (_) {}
  }
}