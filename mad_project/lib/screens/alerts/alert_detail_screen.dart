import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../models/alert_model.dart';

class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({super.key});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  String? _address;
  bool _loadingAddress = false;
  String? _addressError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AlertModel &&
        args.hasLocation &&
        _address == null &&
        !_loadingAddress) {
      _reverseGeocode(args.latitude!, args.longitude!);
    }
  }

  /// Calls Nominatim (OpenStreetMap) — free, no API key needed.
  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() {
      _loadingAddress = true;
      _addressError = null;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=$lat&lon=$lng&addressdetails=1',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'VisionBotApp/1.0 (contact@visionbot.com)',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = (json['display_name'] ?? '').toString().trim();
        final addr = json['address'] as Map<String, dynamic>? ?? {};

        final parts = <String>[];

        final houseNumber = (addr['house_number'] ?? '').toString().trim();
        final road = (addr['road'] ?? addr['street'] ?? '').toString().trim();
        if (houseNumber.isNotEmpty && road.isNotEmpty) {
          parts.add('House $houseNumber, $road');
        } else if (road.isNotEmpty) {
          parts.add(road);
        } else if (houseNumber.isNotEmpty) {
          parts.add('House $houseNumber');
        }

        final neighbourhood = (addr['neighbourhood'] ??
                addr['suburb'] ??
                addr['village'] ??
                addr['hamlet'] ??
                '')
            .toString()
            .trim();
        if (neighbourhood.isNotEmpty) parts.add(neighbourhood);

        final city = (addr['city'] ??
                addr['town'] ??
                addr['municipality'] ??
                addr['county'] ??
                '')
            .toString()
            .trim();
        if (city.isNotEmpty) parts.add(city);

        final state = (addr['state'] ?? '').toString().trim();
        final country = (addr['country'] ?? '').toString().trim();
        if (state.isNotEmpty) parts.add(state);
        if (country.isNotEmpty) parts.add(country);

        final formatted =
            parts.isNotEmpty ? parts.join(', ') : displayName;

        if (mounted) {
          setState(() {
            _address = formatted.isNotEmpty ? formatted : displayName;
            _loadingAddress = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _addressError = 'Could not fetch address';
          _loadingAddress = false;
        });
      }
    }
  }

  // ── Formatting helpers ────────────────────────────────────────────────────
  String _formatDateTime(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)} '
        '${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
  }

  String _formatThreshold(dynamic v) {
    if (v == null) return 'N/A';
    if (v is num) return v.toStringAsFixed(2);
    return v.toString();
  }

  String _prettyType(String raw) {
    final t = raw.toLowerCase().trim();
    if (t == 'unknown_face') return 'Unknown person';
    if (t == 'known_face') return 'Known person';
    if (t == 'motion') return 'Motion detected';
    if (t == 'fire') return 'Fire detected';
    if (t == 'smoke') return 'Smoke detected';
    if (t == 'intruder') return 'Intruder detected';
    if (t.isEmpty) return 'Alert';
    final p = t.replaceAll('_', ' ');
    return '${p[0].toUpperCase()}${p.substring(1)}';
  }

  _TypeStyle _typeStyle(String raw) {
    final t = raw.toLowerCase().trim();
    if (t == 'fire' || t == 'intruder') {
      return _TypeStyle(
          title: _prettyType(raw),
          icon: Icons.warning_rounded,
          accent: const Color(0xFFFF6B6B));
    }
    if (t == 'smoke' || t == 'unknown_face' || t == 'motion') {
      return _TypeStyle(
          title: _prettyType(raw),
          icon: Icons.info_rounded,
          accent: const Color(0xFFFF9800));
    }
    return _TypeStyle(
        title: _prettyType(raw),
        icon: Icons.check_circle_rounded,
        accent: const Color(0xFF45B7D1));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args == null || args is! AlertModel) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _appBar(),
        body: const Center(child: Text('No alert data found')),
      );
    }

    final alert = args;
    final style = _typeStyle(alert.type.toString());
    final createdAtText = _formatDateTime(alert.createdAt);
    final createdAtLocalText = alert.createdAtLocal == null
        ? 'N/A'
        : _formatDateTime(alert.createdAtLocal!);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _appBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _headerCard(
            icon: style.icon,
            title: style.title,
            subtitle: createdAtText,
            accent: style.accent,
          ),
          const SizedBox(height: 14),
          _sectionTitle('Details'),
          const SizedBox(height: 10),
          _infoCard(children: [
            _infoRow(Icons.schedule_rounded, 'created_at', createdAtText),
            _divider(),
            _infoRow(Icons.access_time_rounded, 'created_at_local',
                createdAtLocalText),
            _divider(),
            _infoRow(Icons.camera_alt_outlined, 'lens',
                alert.lens.isEmpty ? 'N/A' : alert.lens),
            _divider(),
            _infoRow(Icons.notes_rounded, 'note',
                alert.note.isEmpty ? 'N/A' : alert.note,
                multiline: true),
            _divider(),
            _infoRow(Icons.tune_rounded, 'threshold',
                _formatThreshold(alert.threshold)),
            _divider(),
            _infoRow(Icons.category_outlined, 'type', style.title),
          ]),

          // ── Location section ──────────────────────────────────────────
          if (alert.hasLocation) ...[
            const SizedBox(height: 20),
            _sectionTitle('Location'),
            const SizedBox(height: 10),
            _locationCard(alert),
          ],
        ],
      ),
    );
  }

  // ── Location card ─────────────────────────────────────────────────────────
  Widget _locationCard(AlertModel alert) {
    final lat = alert.latitude!;
    final lng = alert.longitude!;
    final coordsText =
        '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

    // What to copy: prefer resolved address
    final copyValue = _address ?? coordsText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Human-readable address banner ───────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF06B6D4).withOpacity(0.10),
                const Color(0xFF8B5CF6).withOpacity(0.08),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF06B6D4).withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pin icon
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF06B6D4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Color(0xFF06B6D4), size: 18),
                  ),
                ),
                const SizedBox(width: 12),

                // Address / loading / error
                Expanded(
                  child: _loadingAddress
                      ? Row(children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF06B6D4)),
                          ),
                          const SizedBox(width: 10),
                          Text('Fetching address…',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ])
                      : Text(
                          _address ??
                              (_addressError != null
                                  ? coordsText // fall back to coords
                                  : coordsText),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _addressError != null && _address == null
                                ? Colors.grey.shade500
                                : const Color(0xFF1F2937),
                            height: 1.45,
                          ),
                        ),
                ),

                const SizedBox(width: 8),

                // Copy button
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: copyValue));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Copied to clipboard'),
                      backgroundColor: const Color(0xFF06B6D4),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.copy_rounded,
                        size: 16, color: Color(0xFF06B6D4)),
                  ),
                ),
              ],
            ),
          ),

          // Error note shown below banner when address failed
          if (_addressError != null && _address == null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('Showing raw coordinates (no internet or address unavailable)',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400)),
            ]),
          ],

          const SizedBox(height: 14),
          Container(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 14),

          // ── Raw coordinate rows ─────────────────────────────────────
          _coordRow(
              icon: Icons.my_location_rounded,
              label: 'Latitude',
              value: lat.toStringAsFixed(6)),
          const SizedBox(height: 10),
          _coordRow(
              icon: Icons.my_location_rounded,
              label: 'Longitude',
              value: lng.toStringAsFixed(6)),
          if (alert.locationName != null) ...[
            const SizedBox(height: 10),
            _coordRow(
                icon: Icons.label_rounded,
                label: 'Location name',
                value: alert.locationName!),
          ],
        ],
      ),
    );
  }

  Widget _coordRow(
      {required IconData icon,
      required String label,
      required String value}) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 15, color: const Color(0xFF06B6D4)),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 110,
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
                fontSize: 13)),
      ),
      Expanded(
        child: Text(value,
            style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    ]);
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  PreferredSizeWidget _appBar() => AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Builder(
          builder: (ctx) => Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF1F2937)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text('Alert Details',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      );

  Widget _sectionTitle(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Text(t,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937))),
      );

  Widget _headerCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [
                accent.withOpacity(0.10),
                const Color(0xFF8B5CF6).withOpacity(0.08),
                const Color(0xFF06B6D4).withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                ]),
          ),
        ]),
      );

  Widget _infoCard({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(children: children),
      );

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(height: 1, color: Colors.grey.shade100),
      );

  Widget _infoRow(IconData icon, String label, String value,
      {bool multiline = false}) =>
      Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: const Color(0xFF06B6D4), size: 20),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    height: multiline ? 1.4 : 1.2)),
          ),
        ],
      );
}

class _TypeStyle {
  final String title;
  final IconData icon;
  final Color accent;
  _TypeStyle(
      {required this.title, required this.icon, required this.accent});
}