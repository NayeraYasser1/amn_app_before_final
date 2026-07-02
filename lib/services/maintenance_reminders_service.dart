import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local maintenance reminders shared by the voice assistant and the
/// Maintenance Reminders screen.
///
/// Stored under [prefsKey] as a JSON list of
/// `{"title": String, "due": ISO-8601 String}`.
class MaintenanceRemindersService {
  static const String prefsKey = 'maintenance_reminders_json';

  /// Loads all reminders, seeding the default set only on first use
  /// (missing/invalid key). An explicitly saved empty list stays empty so
  /// deleting every reminder in the edit screen does not resurrect the seeds.
  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    final seeded = <Map<String, dynamic>>[
      {
        'title': 'Engine check',
        'due': now.add(const Duration(days: 14)).toIso8601String(),
      },
      {
        'title': 'Oil change',
        'due': now.add(const Duration(days: 90)).toIso8601String(),
      },
      {
        'title': 'Tire rotation',
        'due': now.add(const Duration(days: 180)).toIso8601String(),
      },
      {
        'title': 'License renewal',
        'due': now.add(const Duration(days: 365)).toIso8601String(),
      },
    ];
    await save(seeded);
    return seeded;
  }

  static Future<void> save(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(items));
  }

  static DateTime dueOf(Map<String, dynamic> item) =>
      DateTime.tryParse((item['due'] ?? '').toString()) ?? DateTime.now();

  /// Whole days from today to the due date (date-only, ignores time of day).
  static int daysUntil(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(due.year, due.month, due.day).difference(today).inDays;
  }

  static String daysLeftLabel(int days) {
    if (days < -1) return 'Overdue by ${-days} days';
    if (days == -1) return 'Overdue since yesterday';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'In $days days';
  }
}
