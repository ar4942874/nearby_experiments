import 'package:flutter/material.dart';
import 'package:nearby_chat_app/connection_screen.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/permission_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// null = still checking, true = all granted, false = something missing.
  bool? _permissionsOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // One-time generalized permission flow: check first, request only missing.
    _ensurePermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final missing = await PermissionService.instance.missingPermissions();
    if (!mounted) return;
    setState(() => _permissionsOk = missing.isEmpty);
  }

  Future<void> _ensurePermissions() async {
    final ok = await PermissionService.instance.ensureAll();
    if (!mounted) return;
    setState(() => _permissionsOk = ok);
  }

  Future<void> _fixPermissions() async {
    final ok = await PermissionService.instance.ensureAll();
    if (!ok) {
      // Permanently denied: fall back to the system settings page.
      await PermissionService.instance.openSettings();
    }
    if (!mounted) return;
    setState(() => _permissionsOk = ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTokens.xxl + 8),
              const Text('Nearby', style: AppTokens.display),
              const SizedBox(height: AppTokens.xs + 2),
              Text('Connect without internet', style: AppTokens.muted(16)),
              const SizedBox(height: AppTokens.xxl + 8),
              if (_permissionsOk == false) ...[
                _PermissionBanner(onFix: _fixPermissions),
                const SizedBox(height: AppTokens.md),
              ],
              _FeatureCard(
                icon: Icons.wifi_tethering_rounded,
                title: 'Start Connection',
                subtitle: 'Host or find a nearby peer',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ConnectionScreen()),
                ),
              ),
              const Spacer(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.xl + 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Text('No internet needed', style: AppTokens.caption),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onFix});

  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: AppTokens.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTokens.dangerWith(0.12),
              borderRadius: BorderRadius.circular(AppTokens.radiusIconBox),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppTokens.danger, size: 22),
          ),
          const SizedBox(width: AppTokens.md - 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Permissions missing', style: AppTokens.h2),
                const SizedBox(height: 2),
                Text('Bluetooth, location & mic access are needed to connect',
                    style: AppTokens.muted(13)),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.sm),
          TextButton(
            onPressed: onFix,
            style: TextButton.styleFrom(
              foregroundColor: AppTokens.accent,
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.md),
            ),
            child: const Text('Fix', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

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
