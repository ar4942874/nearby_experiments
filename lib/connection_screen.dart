import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nearby_chat_app/connection_service.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/feature_selection_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final ConnectionService _conn = ConnectionService.instance;
  late LinkSnapshot _snap;
  StreamSubscription<LinkSnapshot>? _sub;
  final TextEditingController _nameController = TextEditingController(text: 'User');

  @override
  void initState() {
    super.initState();
    _snap = _conn.snapshot;
    _sub = _conn.snapshotStream.listen((s) {
      _snap = s;
      if (mounted) setState(() {});
      if (s.state == LinkState.connected && !_navigated) {
        _navigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FeatureSelectionScreen()),
        );
      }
    });
  }

  bool _navigated = false;

  @override
  void dispose() {
    _sub?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _snap.isConnected;
    final hosting = _snap.state == LinkState.hosting;
    final discovering = _snap.state == LinkState.discovering;

    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: AppTokens.background,
        elevation: 0,
        title: Text('Nearby Connect', style: AppTokens.appBarTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTokens.xxl),
              _StatusCard(snapshot: _snap),
              const SizedBox(height: AppTokens.xl),
              if (!connected) ...[
                TextField(
                  controller: _nameController,
                  decoration: AppTokens.inputDecoration(hint: 'Your name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppTokens.md),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.wifi_tethering_rounded,
                        label: hosting ? 'Starting...' : 'Host',
                        onPressed: hosting || discovering ? null : _host,
                        loading: hosting,
                      ),
                    ),
                    const SizedBox(width: AppTokens.md),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.search_rounded,
                        label: discovering ? 'Searching...' : 'Find Devices',
                        onPressed: hosting || discovering ? null : _discover,
                        loading: discovering,
                      ),
                    ),
                  ],
                ),
                if (discovering && _snap.endpoints.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.lg),
                  Text('Found Devices', style: AppTokens.h2),
                  const SizedBox(height: AppTokens.sm),
                  _DeviceList(
                    endpoints: _snap.endpoints,
                    onTap: (id) => _conn.connectTo(id),
                  ),
                ],
              ] else ...[
                const Spacer(),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTokens.tint,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(Icons.check_circle_rounded, color: AppTokens.accent, size: 40),
                      ),
                      const SizedBox(height: AppTokens.md),
                      Text('Connected!', style: AppTokens.h1),
                      const SizedBox(height: AppTokens.xs),
                      Text(
                        'Connected to ${_snap.connectedEndpointName ?? 'peer'}',
                        style: AppTokens.muted(15),
                      ),
                      const SizedBox(height: AppTokens.xl),
                      FilledButton.icon(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const FeatureSelectionScreen()),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Continue to Features'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTokens.accent,
                          padding: const EdgeInsets.symmetric(horizontal: AppTokens.xl, vertical: AppTokens.md),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
              const SizedBox(height: AppTokens.xl),
              if (connected)
                OutlinedButton.icon(
                  onPressed: () => _conn.disconnect(),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTokens.text,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: AppTokens.md),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
Future<void> _host() async {
    final name = _nameController.text.trim().isEmpty ? 'User' : _nameController.text.trim();
    print('🔵 ConnectionScreen: Starting host with name=$name');
    await _conn.host(name);
    print('🔵 ConnectionScreen: host() returned');
  }

  Future<void> _discover() async {
    final name = _nameController.text.trim().isEmpty ? 'User' : _nameController.text.trim();
    print('🔵 ConnectionScreen: Starting discover with name=$name');
    await _conn.discover(name);
    print('🔵 ConnectionScreen: discover() returned');
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snapshot});
  final LinkSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final connected = snapshot.isConnected;
    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: AppTokens.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: connected ? AppTokens.tint : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              connected ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
              color: connected ? AppTokens.accent : Colors.grey.shade400,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Connected' : 'Not Connected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: connected ? AppTokens.text : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  snapshot.status,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.endpoints, required this.onTap});
  final Map<String, String> endpoints;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final entries = endpoints.entries.toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final e = entries[i];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusControl),
            child: InkWell(
              onTap: () => onTap(e.key),
              borderRadius: BorderRadius.circular(AppTokens.radiusControl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                  border: AppTokens.cardBorder,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTokens.tint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person_outline_rounded, color: AppTokens.accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTokens.text)),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: disabled ? Colors.grey.shade200 : AppTokens.accentWith(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.accent))
              else
                Icon(icon, size: 20, color: disabled ? Colors.grey.shade400 : AppTokens.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: disabled ? Colors.grey.shade400 : AppTokens.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}