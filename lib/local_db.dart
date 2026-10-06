import 'package:hive_flutter/hive_flutter.dart';

class ChatMessage {
  final bool self;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.self,
    required this.text,
    required this.timestamp,
  });
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 0;

  @override
  ChatMessage read(BinaryReader reader) {
    return ChatMessage(
      self: reader.readBool(),
      text: reader.readString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer.writeBool(obj.self);
    writer.writeString(obj.text);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
  }
}

class LocalDB {
  static const String _boxName = 'chat_messages';
  static Box<ChatMessage>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ChatMessageAdapter());
    _box = await Hive.openBox<ChatMessage>(_boxName);
  }

  static Future<void> addMessage(ChatMessage message) async {
    await _box?.add(message);
  }

  static List<ChatMessage> getAllMessages() {
    return _box?.values.toList() ?? [];
  }

  static Future<void> clearAll() async {
    await _box?.clear();
  }

  static Future<void> deleteMessage(int index) async {
    await _box?.deleteAt(index);
  }

  static int get messageCount => _box?.length ?? 0;
}
