import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/emergency_event.dart';
import '../services/emergency_history_service.dart';
import '../services/usage_logger.dart';
import '../theme/app_colors.dart';
import 'settings_screen.dart';
import 'voice_assistant_screen.dart';

const Color _background = AppColors.background;
const Color _card = AppColors.card;
const Color _border = AppColors.border;
const Color _red = AppColors.red;
const Color _green = AppColors.green;
const Color _orange = AppColors.orange;
const Color _blue = AppColors.blue;
const Color _purple = AppColors.purple;
const Color _muted = AppColors.muted;

enum _HistoryFilter { all, sos, service, parking, voice, calls }

class EmergencyHistoryScreen extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;

  const EmergencyHistoryScreen({super.key, this.onLocaleChanged});

  @override
  State<EmergencyHistoryScreen> createState() => _EmergencyHistoryScreenState();
}

class _EmergencyHistoryScreenState extends State<EmergencyHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;
  EmergencyEvent? _selectedEvent;
  // Held in a field so each rebuild (filter tap, opening details) reuses the
  // same subscription instead of creating a fresh generator that flashes the
  // loading spinner and re-reads prefs.
  late final Stream<List<EmergencyEvent>> _eventsStream =
      EmergencyHistoryService.eventsStream();

  @override
  void initState() {
    super.initState();
    UsageLogger.logScreenView('EmergencyHistoryScreen');
    EmergencyHistoryService.refresh();
  }

  void _openBottomTab(int index) {
    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    if (index == 1) {
      UsageLogger.logAction('voice_assistant_open');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VoiceAssistantScreen()),
      );
      return;
    }

    if (index == 2) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SettingsScreen(onLocaleChanged: widget.onLocaleChanged),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDetails = _selectedEvent != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _background,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: showDetails
                ? _buildDetails(_selectedEvent!)
                : _buildHistoryStream(),
          ),
        ),
        bottomNavigationBar: showDetails
            ? null
            : _HistoryBottomNavigationBar(
                currentIndex: 2,
                onTap: _openBottomTab,
              ),
      ),
    );
  }

  Widget _buildHistoryStream() {
    return StreamBuilder<List<EmergencyEvent>>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <EmergencyEvent>[];
        final filtered = _filteredEvents(events);

        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            events.isEmpty;
        final empty = !loading && filtered.isEmpty;
        // Events are rendered lazily so a full 200-item history doesn't build
        // every card up front. Index 0 is the header; the body is either a
        // single loading/empty placeholder or one item per event.
        final bodyCount = (loading || empty) ? 1 : filtered.length;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: 1 + bodyCount,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HistoryTopBar(
                    title: 'History',
                    showBack: true,
                    onBack: () => Navigator.pop(context),
                    onRefresh: EmergencyHistoryService.refresh,
                  ),
                  const SizedBox(height: 18),
                  _FilterChips(
                    selected: _filter,
                    events: events,
                    onSelected: (filter) {
                      UsageLogger.logAction('history_${filter.name}');
                      setState(() => _filter = filter);
                    },
                  ),
                  const SizedBox(height: 18),
                ],
              );
            }

            if (loading) {
              return const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: _red)),
              );
            }
            if (empty) {
              return _EmptyHistory(filter: _filter);
            }

            final event = filtered[index - 1];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index - 1 == filtered.length - 1 ? 0 : 10,
              ),
              child: _HistoryEventCard(
                event: event,
                onTap: () {
                  UsageLogger.logAction(
                    'history_detail_open',
                    data: {'type': event.type, 'title': event.title},
                  );
                  setState(() => _selectedEvent = event);
                },
                onDelete: () => _deleteEvent(event),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEvent(EmergencyEvent event) async {
    await EmergencyHistoryService.deleteEvent(event.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${event.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => EmergencyHistoryService.restoreEvent(event),
        ),
      ),
    );
  }

  List<EmergencyEvent> _filteredEvents(List<EmergencyEvent> events) {
    return events.where((event) {
      return switch (_filter) {
        _HistoryFilter.all => true,
        _HistoryFilter.sos => _kindForType(event.type) == _HistoryFilter.sos,
        _HistoryFilter.service =>
          _kindForType(event.type) == _HistoryFilter.service,
        _HistoryFilter.parking =>
          _kindForType(event.type) == _HistoryFilter.parking,
        _HistoryFilter.voice =>
          _kindForType(event.type) == _HistoryFilter.voice,
        _HistoryFilter.calls =>
          _kindForType(event.type) == _HistoryFilter.calls,
      };
    }).toList();
  }

  Widget _buildDetails(EmergencyEvent event) {
    final kind = _kindForType(event.type);

    return ListView(
      key: ValueKey('details_${event.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _HistoryTopBar(
          title: 'Activity Details',
          showBack: true,
          onBack: () => setState(() => _selectedEvent = null),
          onRefresh: EmergencyHistoryService.refresh,
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              _HistoryGlyph(kind: kind, large: true),
              const SizedBox(height: 14),
              Text(
                event.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _entryAccent(kind),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _formatDateTime(event.timestamp),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _DetailRows(
          rows: [
            _DetailRowData('Type', _labelForFilter(kind)),
            _DetailRowData(
              'Status',
              event.status,
              color: _statusColor(event.status),
            ),
            if ((event.description ?? '').isNotEmpty)
              _DetailRowData('Description', event.description!),
            if ((event.location ?? '').isNotEmpty)
              _DetailRowData('Location', event.location!),
            _DetailRowData('Recorded', _formatDateTime(event.timestamp)),
          ],
        ),
      ],
    );
  }
}

class _HistoryTopBar extends StatelessWidget {
  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _HistoryTopBar({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showBack)
            Positioned(
              left: 0,
              child: _HeaderButton(icon: Icons.chevron_left, onTap: onBack),
            ),
          Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: _HeaderButton(icon: Icons.refresh, onTap: onRefresh),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final _HistoryFilter selected;
  final List<EmergencyEvent> events;
  final ValueChanged<_HistoryFilter> onSelected;

  const _FilterChips({
    required this.selected,
    required this.events,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filters = _HistoryFilter.values;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in filters)
          _FilterChipButton(
            label: '${_labelForFilter(filter)} (${_countFor(filter, events)})',
            selected: selected == filter,
            onTap: () => onSelected(filter),
          ),
      ],
    );
  }

  int _countFor(_HistoryFilter filter, List<EmergencyEvent> events) {
    if (filter == _HistoryFilter.all) return events.length;
    return events.where((event) => _kindForType(event.type) == filter).length;
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? _red : _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _red : _border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryEventCard extends StatelessWidget {
  final EmergencyEvent event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryEventCard({
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final kind = _kindForType(event.type);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _HistoryGlyph(kind: kind),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDateTime(event.timestamp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((event.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          event.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  event.status,
                  style: TextStyle(
                    color: _statusColor(event.status),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  icon: const Icon(Icons.close, color: _muted, size: 18),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final _HistoryFilter filter;

  const _EmptyHistory({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 50),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Text(
        filter == _HistoryFilter.all
            ? 'No real activity has been recorded yet.'
            : 'No ${_labelForFilter(filter).toLowerCase()} activity yet.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _muted, fontSize: 13),
      ),
    );
  }
}

class _DetailRowData {
  final String label;
  final String value;
  final Color? color;

  const _DetailRowData(this.label, this.value, {this.color});
}

class _DetailRows extends StatelessWidget {
  final List<_DetailRowData> rows;

  const _DetailRows({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _DetailRow(row: rows[i]),
            if (i != rows.length - 1)
              Divider(
                color: _border.withValues(alpha: 0.7),
                height: 1,
                thickness: 1,
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final _DetailRowData row;

  const _DetailRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: row.color ?? Colors.white,
                fontSize: 12,
                fontWeight: row.color == null
                    ? FontWeight.w500
                    : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryGlyph extends StatelessWidget {
  final _HistoryFilter kind;
  final bool large;

  const _HistoryGlyph({required this.kind, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 60.0 : 34.0;
    final accent = _entryAccent(kind);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Center(
        child: kind == _HistoryFilter.sos
            ? Text(
                'SOS',
                style: TextStyle(
                  color: _red,
                  fontSize: large ? 16 : 11,
                  fontWeight: FontWeight.w800,
                ),
              )
            : Icon(_entryIcon(kind), color: accent, size: large ? 32 : 21),
      ),
    );
  }
}

class _HistoryBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _HistoryBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _background,
        border: Border(
          top: BorderSide(color: _border.withValues(alpha: 0.48), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              _BottomNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _BottomNavItem(
                icon: Icons.mic_none,
                label: 'Assistant',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _BottomNavItem(
                icon: Icons.history,
                label: 'History',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _BottomNavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.45);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 27),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_HistoryFilter _kindForType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('sos')) return _HistoryFilter.sos;
  if (normalized.contains('parking')) return _HistoryFilter.parking;
  if (normalized.contains('voice')) return _HistoryFilter.voice;
  if (normalized.contains('call') || normalized.contains('contact')) {
    return _HistoryFilter.calls;
  }
  return _HistoryFilter.service;
}

String _labelForFilter(_HistoryFilter filter) {
  return switch (filter) {
    _HistoryFilter.all => 'All',
    _HistoryFilter.sos => 'SOS',
    _HistoryFilter.service => 'Service',
    _HistoryFilter.parking => 'Parking',
    _HistoryFilter.voice => 'Voice',
    _HistoryFilter.calls => 'Calls',
  };
}

Color _entryAccent(_HistoryFilter kind) {
  return switch (kind) {
    _HistoryFilter.sos => _red,
    _HistoryFilter.service => _green,
    _HistoryFilter.parking => _blue,
    _HistoryFilter.voice => _purple,
    _HistoryFilter.calls => _red,
    _HistoryFilter.all => _muted,
  };
}

IconData _entryIcon(_HistoryFilter kind) {
  return switch (kind) {
    _HistoryFilter.sos => Icons.warning_amber_rounded,
    _HistoryFilter.service => Icons.build,
    _HistoryFilter.parking => Icons.local_parking,
    _HistoryFilter.voice => Icons.mic_none,
    _HistoryFilter.calls => Icons.call_outlined,
    _HistoryFilter.all => Icons.history,
  };
}

Color _statusColor(String status) {
  final normalized = status.toLowerCase();
  if (normalized == 'cancelled' || normalized == 'failed') return _orange;
  if (normalized == 'connected' ||
      normalized == 'completed' ||
      normalized == 'resolved') {
    return _green;
  }
  if (normalized == 'in progress' || normalized == 'started') return _blue;
  return _muted;
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][local.month - 1];
  final hour12 = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$month ${local.day}, ${local.year} - $hour12:$minute $suffix';
}
