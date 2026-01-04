import 'package:flutter/material.dart';
import '../../models/alert_model.dart';

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key});

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
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
    final pretty = t.replaceAll('_', ' ');
    return pretty[0].toUpperCase() + pretty.substring(1);
  }

  _TypeStyle _typeStyle(String raw) {
    final t = raw.toLowerCase().trim();
    if (t == 'fire' || t == 'intruder') {
      return _TypeStyle(
        title: _prettyType(raw),
        icon: Icons.warning_rounded,
        accent: const Color(0xFFFF6B6B),
        softBg: const Color(0xFFFF6B6B),
      );
    }
    if (t == 'smoke' || t == 'unknown_face' || t == 'motion') {
      return _TypeStyle(
        title: _prettyType(raw),
        icon: Icons.info_rounded,
        accent: const Color(0xFFFF9800),
        softBg: const Color(0xFFFF9800),
      );
    }
    return _TypeStyle(
      title: _prettyType(raw),
      icon: Icons.check_circle_rounded,
      accent: const Color(0xFF45B7D1),
      softBg: const Color(0xFF45B7D1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args == null || args is! AlertModel) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
            ).createShader(bounds),
            child: const Text(
              'Alert Detail',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        body: const Center(child: Text('No alert data found')),
      );
    }

    final alert = args;

    final typeRaw = alert.type.toString();
    final style = _typeStyle(typeRaw);

    final typeText = typeRaw.isEmpty ? 'N/A' : style.title;
    final lensText = alert.lens.isEmpty ? 'N/A' : alert.lens;
    final noteText = alert.note.isEmpty ? 'N/A' : alert.note;

    final createdAtText = _formatDateTime(alert.createdAt);

    final createdAtLocalRaw = alert.createdAtLocal;
    String createdAtLocalText;
    if (createdAtLocalRaw == null) {
      createdAtLocalText = 'N/A';
    } else    createdAtLocalText = _formatDateTime(createdAtLocalRaw);
  

    final thresholdText = _formatThreshold(alert.threshold);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1F2937),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text(
            'Alert Details',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _headerCard(
            icon: style.icon,
            title: typeText,
            subtitle: createdAtText,
            accent: style.accent,
          ),
          const SizedBox(height: 14),
          _sectionTitle('Details'),
          const SizedBox(height: 10),
          _infoCard(
            children: [
              _infoRow(
                icon: Icons.schedule_rounded,
                label: 'created_at',
                value: createdAtText,
              ),
              _divider(),
              _infoRow(
                icon: Icons.access_time_rounded,
                label: 'created_at_local',
                value: createdAtLocalText,
              ),
              _divider(),
              _infoRow(
                icon: Icons.camera_alt_outlined,
                label: 'lens',
                value: lensText,
              ),
              _divider(),
              _infoRow(
                icon: Icons.notes_rounded,
                label: 'note',
                value: noteText,
                multiline: true,
              ),
              _divider(),
              _infoRow(
                icon: Icons.tune_rounded,
                label: 'threshold',
                value: thresholdText,
              ),
              _divider(),
              _infoRow(
                icon: Icons.category_outlined,
                label: 'type',
                value: typeText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }

  Widget _headerCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.10),
            const Color(0xFF8B5CF6).withOpacity(0.08),
            const Color(0xFF06B6D4).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
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
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(height: 1, color: Colors.grey.shade100),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    bool multiline = false,
  }) {
    return Row(
      crossAxisAlignment: multiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.circle, size: 0),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF06B6D4), size: 20),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              height: multiline ? 1.4 : 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeStyle {
  final String title;
  final IconData icon;
  final Color accent;
  final Color softBg;

  _TypeStyle({
    required this.title,
    required this.icon,
    required this.accent,
    required this.softBg,
  });
}
