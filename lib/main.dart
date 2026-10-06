import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nearby_chat_app/connection_service.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/home_screen.dart';
import 'package:nearby_chat_app/local_db.dart';
import 'package:nearby_chat_app/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDB.init();
  await NotificationService.instance.initialize();

  // Track app lifecycle globally so we know when the app goes to background.
  WidgetsBinding.instance.addObserver(_appLifecycleObserver);

  // Global payload listener: always active (even when chat screen is closed).
  // Handles storage + notifications so incoming messages are never lost.
  ConnectionService.instance.payloadStream.listen((payload) {
    if (payload.tag == ConnectionService.tagChat) {
      _handleIncomingChat(payload.text);
    }
  });

  runApp(const NearbyConnectApp());
}

/// Global app lifecycle state.
AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

final _AppLifecycleObserver _appLifecycleObserver = _AppLifecycleObserver();

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
  }
}

/// Handles an incoming chat message: persists it and shows a notification
/// when the chat screen is not visible or the app is in the background.
Future<void> _handleIncomingChat(String text) async {
  debugPrint('💬 Global chat received: $text');
  final chatMessage = ChatMessage(
    self: false,
    text: text,
    timestamp: DateTime.now(),
  );
  await LocalDB.addMessage(chatMessage);

  final appInForeground = _appLifecycleState == AppLifecycleState.resumed;
  final shouldNotify = !_isChatScreenVisible || !appInForeground;
  if (shouldNotify) {
    debugPrint('💬 Showing notification for: $text');
    await NotificationService.instance.showChatNotification(
      senderName:
          ConnectionService.instance.snapshot.connectedEndpointName ?? 'Nearby Peer',
      message: text,
      payload: 'chat',
    );
  }
}

class NearbyConnectApp extends StatelessWidget {
  const NearbyConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nearby Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTokens.accent,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppTokens.background,
      ),
      home: const HomeScreen(),
    );
  }
}

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

/// Track if chat screen is currently visible in the foreground.
bool _isChatScreenVisible = false;

class _ChatHomePageState extends State<ChatHomePage> {
  final ConnectionService _conn = ConnectionService.instance;
  LinkSnapshot _snap = ConnectionService.instance.snapshot;
  StreamSubscription<LinkSnapshot>? _snapSub;
  StreamSubscription<AppPayload>? _payloadSub;

  List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isChatScreenVisible = true;
    _loadMessages();

    _snapSub = _conn.snapshotStream.listen((snapshot) {
      _snap = snapshot;
      if (mounted) setState(() {});
    });
    // UI-only listener: the global listener in main() handles storage +
    // notifications, so here we just refresh the visible message list.
    _payloadSub = _conn.payloadStream.listen((payload) {
      if (payload.tag == ConnectionService.tagChat) _onIncoming(payload.text);
    });
  }

  void _loadMessages() {
    final stored = LocalDB.getAllMessages();
    if (stored.isNotEmpty) {
      setState(() {
        _messages = stored;
      });
    }
  }

  Future<void> _saveMessage(ChatMessage message) async {
    await LocalDB.addMessage(message);
  }

  Future<void> _onIncoming(String text) async {
    debugPrint('💬 Chat UI received message: $text');
    final chatMessage = ChatMessage(
      self: false,
      text: text,
      timestamp: DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _messages.add(chatMessage);
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    _messageController.clear();
    if (!mounted) return;

    final chatMessage = ChatMessage(
      self: true,
      text: messageText,
      timestamp: DateTime.now(),
    );
    await _saveMessage(chatMessage);
    setState(() {
      _messages.add(chatMessage);
    });

    try {
      debugPrint('💬 Chat sending message: $messageText');
      await _conn.sendChat(messageText);
      debugPrint('💬 Chat message sent successfully');
    } catch (e) {
      debugPrint('💬 Chat send error: $e');
      _showSnackBar('Send failed: $e');
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty) _messages.removeLast();
      });
    }
  }

  void _clearChat() async {
    await LocalDB.clearAll();
    setState(() {
      _messages.clear();
    });
    _showSnackBar('Chat clear ho gaya');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _isChatScreenVisible = false;
    _messageController.dispose();
    _snapSub?.cancel();
    _payloadSub?.cancel();
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
          'Nearby Chat',
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
        actions: [
          if (connected) ...[
            IconButton(
              icon: Icon(Icons.clear_all_rounded, color: AppTokens.text),
              onPressed: _clearChat,
              tooltip: 'Clear Chat',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildStatusCard(connected, peerName),
          const Divider(height: 1, color: AppTokens.border),
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),
          ),
          if (connected) _buildMessageInput(),
          if (!connected)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Not connected. Go back to establish connection.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool connected, String peerName) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
          const SizedBox(width: 16),
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
                  connected ? 'Chatting with $peerName' : 'Establish connection first',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTokens.tint,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: AppTokens.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Abhi tak koi message nahi',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppTokens.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hosting start karein ya devices discover karein',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment:
                message.self ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.self ? AppTokens.accent : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: message.self ? null : Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          color: message.self ? Colors.white : AppTokens.text,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: message.self
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    final connected = _snap.isConnected;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
        decoration: BoxDecoration(
          color: AppTokens.background,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: connected ? 'Message type karein...' : 'Connect karein pehle',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppTokens.accent, width: 1.5),
                  ),
                ),
                enabled: connected,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: connected ? _sendMessage : null,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: connected ? AppTokens.accent : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'abhi';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hour ago';

    return '${diff.inDays} din ago';
  }
}


