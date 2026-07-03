import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
// Hide latlong2's `Path` so it doesn't clash with dart:ui's Path.
import 'package:latlong2/latlong.dart' hide Path;

const Color _bg = Color(0xFF020607);
const Color _card = Color(0xFF121417);
const Color _border = Color(0xFF2D3238);
const Color _red = Color(0xFFE81218);
const Color _muted = Color(0xFFB7BABF);

const String _osmTileTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

// The destination the user confirmed on the map.
class PickedDestination {
  final double latitude;
  final double longitude;
  final String label;

  const PickedDestination({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

// A place returned by the search.
class _Suggestion {
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;

  const _Suggestion({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

// A full-screen draggable map. The user pans so the centre pin sits on their
// destination (or searches to jump the map there), then confirms. Uses free,
// keyless OpenStreetMap tiles + Nominatim, so no Google Maps API key is needed.
class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const MapPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  bool _confirming = false;
  List<_Suggestion> _suggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Search automatically a moment after the user stops typing (like Maps).
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), _runSearch);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Search for places and show a tappable results list (biased to the
  // starting area).
  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _suggestions = [];
    });
    try {
      const span = 2.0;
      final params = <String, String>{
        'q': query,
        'format': 'json',
        'limit': '15',
        'viewbox':
            '${widget.initialLng - span},${widget.initialLat + span},'
            '${widget.initialLng + span},${widget.initialLat - span}',
        'bounded': '0',
      };
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
      final response = await http
          .get(
            uri,
            headers: {'User-Agent': 'amn_app/1.0 (safety assistance app)'},
          )
          .timeout(const Duration(seconds: 8));
      final list = jsonDecode(response.body) as List;
      final results = list.map((item) {
        final map = item as Map<String, dynamic>;
        final display = (map['display_name'] ?? '').toString();
        final name = display.isEmpty ? query : display.split(',').first.trim();
        return _Suggestion(
          name: name,
          displayName: display,
          latitude: double.parse(map['lat'].toString()),
          longitude: double.parse(map['lon'].toString()),
        );
      }).toList();
      if (!mounted) return;
      setState(() => _suggestions = results);
      if (results.isEmpty) _showSnack('No place matched "$query".');
    } catch (_) {
      _showSnack('Search failed. Check your connection.');
    }
    if (mounted) setState(() => _searching = false);
  }

  // Move the map to a chosen search result.
  void _goToSuggestion(_Suggestion suggestion) {
    FocusScope.of(context).unfocus();
    _mapController.move(
      LatLng(suggestion.latitude, suggestion.longitude),
      16,
    );
    setState(() {
      _suggestions = [];
      _searchController.text = suggestion.name;
    });
  }

  // Turn the centred point into an address label.
  Future<String> _reverseLabel(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'format': 'json',
        'zoom': '18',
      });
      final response = await http
          .get(
            uri,
            headers: {'User-Agent': 'amn_app/1.0 (safety assistance app)'},
          )
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = data['display_name']?.toString();
      if (name == null || name.isEmpty) return 'Pinned location';
      return name.split(',').take(3).join(',').trim();
    } catch (_) {
      return 'Pinned location';
    }
  }

  void _recenter() {
    _mapController.move(
      LatLng(widget.initialLat, widget.initialLng),
      15,
    );
  }

  void _zoomIn() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + 1).clamp(3, 19));
  }

  void _zoomOut() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom - 1).clamp(3, 19));
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    final center = _mapController.camera.center;
    final label = await _reverseLabel(center);
    if (!mounted) return;
    Navigator.pop(
      context,
      PickedDestination(
        latitude: center.latitude,
        longitude: center.longitude,
        label: label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.initialLat, widget.initialLng),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: _osmTileTemplate,
                userAgentPackageName: 'com.example.amn_app',
                maxZoom: 19,
              ),
              const _OsmAttribution(),
            ],
          ),

          // Fixed centre pin — the map moves underneath it.
          const IgnorePointer(
            child: Center(
              child: Padding(
                // Lift the icon so its tip marks the exact centre.
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_pin, color: _red, size: 46),
              ),
            ),
          ),

          // Top bar: back + search + results list.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _RoundIcon(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  textInputAction: TextInputAction.search,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Search a place or address',
                                    hintStyle: TextStyle(color: _muted),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: _onSearchChanged,
                                  onSubmitted: (_) => _runSearch(),
                                ),
                              ),
                              IconButton(
                                onPressed: _searching ? null : _runSearch,
                                icon: _searching
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _red,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: _border, height: 1),
                        itemBuilder: (context, index) {
                          final s = _suggestions[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: _red,
                              size: 20,
                            ),
                            title: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              s.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                            onTap: () => _goToSuggestion(s),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Map controls: recenter, zoom in, zoom out.
          Positioned(
            right: 12,
            bottom: 170,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapControl(icon: Icons.my_location, onTap: _recenter),
                const SizedBox(height: 12),
                _MapControl(icon: Icons.add, onTap: _zoomIn),
                const SizedBox(height: 8),
                _MapControl(icon: Icons.remove, onTap: _zoomOut),
              ],
            ),
          ),

          // Bottom confirm panel.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, color: _muted, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Drag the map so the pin is on your destination, '
                              'or search above.',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _confirming ? null : _confirm,
                        icon: _confirming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _confirming ? 'Setting…' : 'Set this destination',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      shape: const CircleBorder(side: BorderSide(color: _border)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControl({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.black87, size: 24),
        ),
      ),
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: const Text(
          '© OpenStreetMap',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
    );
  }
}
