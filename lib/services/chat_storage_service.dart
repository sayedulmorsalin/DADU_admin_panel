import 'package:shared_preferences/shared_preferences.dart';

class ChatStorageService {
  static const String _prefix = 'chat_last_seen_';

  /// Saves the current time as the last seen timestamp for a specific user thread.
  static Future<void> updateLastSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().toIso8601String();
    await prefs.setString('$_prefix$userId', now);
  }

  /// Gets the last seen timestamp for a specific user thread.
  /// Returns a very old date if never seen.
  static Future<DateTime> getLastSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenStr = prefs.getString('$_prefix$userId');
    if (lastSeenStr == null) {
      return DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    }
    return DateTime.parse(lastSeenStr).toUtc();
  }

  /// Bulk version to get last seen for multiple users (useful for the threads list)
  static Future<Map<String, DateTime>> getAllLastSeen(List<String> userIds) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, DateTime> results = {};
    for (final id in userIds) {
      final lastSeenStr = prefs.getString('$_prefix$id');
      if (lastSeenStr != null) {
        results[id] = DateTime.parse(lastSeenStr).toUtc();
      } else {
        results[id] = DateTime.fromMillisecondsSinceEpoch(0).toUtc();
      }
    }
    return results;
  }

  // --- Pinning Methods ---
  static const String _pinKey = 'chat_pinned_users';

  /// Returns a set of pinned user IDs.
  static Future<Set<String>> getPinnedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pinned = prefs.getStringList(_pinKey) ?? [];
    return pinned.toSet();
  }

  /// Pins or unpins a user.
  static Future<void> togglePin(String userId, bool pin) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> pinned = (prefs.getStringList(_pinKey) ?? []).toSet();
    if (pin) {
      pinned.add(userId);
    } else {
      pinned.remove(userId);
    }
    await prefs.setStringList(_pinKey, pinned.toList());
  }
}
