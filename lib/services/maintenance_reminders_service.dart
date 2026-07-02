import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local maintenance reminders shared by the voice assistant, the
/// Maintenance Reminders screen and the Home alert card.
///
/// Stored under [prefsKey] as a JSON list of
/// `{"title": String, "due": ISO-8601 String, "pinned": bool?}`.
/// At most one item is pinned; the pinned item is the one featured on the
/// Home screen alert card.
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

  /// The 10 standard maintenance-by-vehicle-system categories offered when
  /// adding a reminder (typing a custom title is still allowed).
  static const List<String> presetTitles = [
    'Engine maintenance',
    'Brake maintenance',
    'Tyre and wheel maintenance',
    'Battery and electrical maintenance',
    'Transmission maintenance',
    'Steering and suspension maintenance',
    'Cooling-system maintenance',
    'Air-conditioning maintenance',
    'Body and exterior maintenance',
    'Interior maintenance',
  ];

  /// Icon for a reminder title. Keyword-matched so typed titles get the
  /// right icon too. Air-conditioning must be checked before cooling.
  static IconData iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('air') && t.contains('condition')) return Icons.ac_unit;
    if (t.contains('engine')) return Icons.car_repair;
    if (t.contains('brake')) return Icons.do_not_disturb_on;
    if (t.contains('tyre') || t.contains('tire') || t.contains('wheel')) {
      return Icons.tire_repair;
    }
    if (t.contains('battery') || t.contains('electric')) {
      return Icons.battery_charging_full;
    }
    if (t.contains('transmission') ||
        t.contains('clutch') ||
        t.contains('gearbox')) {
      return Icons.settings;
    }
    if (t.contains('steering') || t.contains('suspension')) {
      return Icons.compress;
    }
    if (t.contains('cooling') ||
        t.contains('coolant') ||
        t.contains('radiator')) {
      return Icons.thermostat;
    }
    if (t.contains('body') ||
        t.contains('exterior') ||
        t.contains('wash') ||
        t.contains('polish')) {
      return Icons.local_car_wash;
    }
    if (t.contains('interior') || t.contains('seat')) return Icons.event_seat;
    if (t.contains('oil')) return Icons.opacity;
    if (t.contains('license') || t.contains('licence')) return Icons.badge;
    return Icons.build;
  }

  /// The reminder featured on the Home alert card: the pinned one if any,
  /// otherwise the engine reminder, otherwise the nearest due.
  static Map<String, dynamic>? homeAlertItem(
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return null;
    final sorted = [...items]..sort((a, b) => dueOf(a).compareTo(dueOf(b)));
    for (final item in sorted) {
      if (item['pinned'] == true) return item;
    }
    return sorted.firstWhere(
      (item) =>
          (item['title'] ?? '').toString().toLowerCase().contains('engine'),
      orElse: () => sorted.first,
    );
  }
}
