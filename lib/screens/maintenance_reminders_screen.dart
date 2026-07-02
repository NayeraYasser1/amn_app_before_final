import 'package:flutter/material.dart';

import '../services/maintenance_reminders_service.dart';

/// View / add / edit / delete maintenance reminders.
///
/// Backed by the same SharedPreferences JSON the voice assistant reads
/// ("show maintenance reminders" / "when is my next maintenance").
class MaintenanceRemindersScreen extends StatefulWidget {
  const MaintenanceRemindersScreen({super.key});

  @override
  State<MaintenanceRemindersScreen> createState() =>
      _MaintenanceRemindersScreenState();
}

class _MaintenanceRemindersScreenState
    extends State<MaintenanceRemindersScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await MaintenanceRemindersService.load();
    _sortByDue(items);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _sortByDue(List<Map<String, dynamic>> items) {
    items.sort(
      (a, b) => MaintenanceRemindersService.dueOf(
        a,
      ).compareTo(MaintenanceRemindersService.dueOf(b)),
    );
  }

  Future<void> _persist() async {
    _sortByDue(_items);
    await MaintenanceRemindersService.save(_items);
    if (mounted) setState(() {});
  }

  Future<void> _addOrEdit({int? index}) async {
    final editing = index != null;
    final titleController = TextEditingController(
      text: editing ? (_items[index]['title'] ?? '').toString() : '',
    );
    DateTime due = editing
        ? MaintenanceRemindersService.dueOf(_items[index])
        : DateTime.now().add(const Duration(days: 30));

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                editing ? 'Edit Reminder' : 'Add Reminder',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: !editing,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Oil change',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: due,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 5),
                        ),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark(),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => due = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Due ${_formatDate(due)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit_calendar,
                            color: Colors.grey[500],
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    final entry = {
      'title': titleController.text.trim(),
      'due': due.toIso8601String(),
    };
    if (editing) {
      _items[index] = entry;
    } else {
      _items.add(entry);
    }
    await _persist();
  }

  Future<void> _delete(int index) async {
    final removed = _items.removeAt(index);
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${removed['title']}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            _items.add(removed);
            await _persist();
          },
        ),
      ),
    );
  }

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  /// Whole days from today to the due date (date-only, ignores time of day).
  int _daysUntil(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(due.year, due.month, due.day).difference(today).inDays;
  }

  String _relativeLabel(int days) {
    if (days < -1) return 'Overdue by ${-days} days';
    if (days == -1) return 'Overdue since yesterday';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'In $days days';
  }

  Color _relativeColor(int days) {
    if (days < 0) return Colors.redAccent;
    if (days <= 7) return Colors.amber;
    return Colors.grey[400]!;
  }

  IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('oil')) return Icons.opacity;
    if (t.contains('tire') || t.contains('tyre')) return Icons.tire_repair;
    if (t.contains('license') || t.contains('licence')) return Icons.badge;
    if (t.contains('battery')) return Icons.battery_charging_full;
    if (t.contains('brake')) return Icons.do_not_disturb_on;
    return Icons.build;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Maintenance Reminders',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Reminder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build_circle_outlined,
                        color: Colors.grey[700], size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'No maintenance reminders',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap Add Reminder to create one.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final title = (item['title'] ?? '').toString();
                  final due = MaintenanceRemindersService.dueOf(item);
                  final days = _daysUntil(due);
                  return Material(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _addOrEdit(index: index),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _iconFor(title),
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(due),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _relativeLabel(days),
                                    style: TextStyle(
                                      color: _relativeColor(days),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _delete(index),
                              icon: Icon(
                                Icons.close,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
