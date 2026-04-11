import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/alert_model.dart';
import '../../services/alert_service.dart';
import '../../routes/app_routes.dart';

class LogsHistoryScreen extends StatefulWidget {
  const LogsHistoryScreen({super.key});

  @override
  State<LogsHistoryScreen> createState() => _LogsHistoryScreenState();
}

class _LogsHistoryScreenState extends State<LogsHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AlertService _alertService = AlertService();

  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Fire',
    'Smoke',
    'Unknown Face',
    'Motion',
    'System',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _normalizeType(String raw) {
    var t = raw.trim().toLowerCase();
    if (t.contains('.')) t = t.split('.').last;
    t = t.replaceAll(' ', '').replaceAll('-', '');
    return t;
  }

  bool _matchesFilter(AlertModel alert) {
    if (_selectedFilter == 'All') return true;
    final typeNorm = _normalizeType(alert.type.toString());
    final filterNorm =
        _selectedFilter.toLowerCase().replaceAll(' ', '');
    if (filterNorm == 'unknownface') {
      return typeNorm == 'unknown_face' || typeNorm == 'unknownface';
    }
    return typeNorm == filterNorm;
  }

  Color _getTypeColor(String type) {
    final t = _normalizeType(type);
    if (t == 'fire') return const Color(0xFFFF6B6B);
    if (t == 'smoke') return const Color(0xFFF59E0B);
    if (t.contains('unknown')) return const Color(0xFFEC4899);
    if (t == 'motion') return const Color(0xFF45B7D1);
    return const Color(0xFF8B5CF6);
  }

  IconData _getTypeIcon(String type) {
    final t = _normalizeType(type);
    if (t == 'fire') return Icons.local_fire_department_rounded;
    if (t == 'smoke') return Icons.cloud_rounded;
    if (t.contains('unknown')) return Icons.person_off_rounded;
    if (t == 'motion') return Icons.directions_run_rounded;
    return Icons.info_rounded;
  }

  String _formatType(String type) {
    final t = _normalizeType(type);
    if (t == 'unknown_face' || t == 'unknownface') {
      return 'Unknown Person';
    }
    if (t.isEmpty) return 'Alert';
    return t
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  bool _isFaceAlert(String type) {
    final t = _normalizeType(type);
    return t == 'unknown_face' ||
        t == 'unknownface' ||
        t == 'known_face' ||
        t == 'knownface' ||
        t == 'intruder';
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF1F2937)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text(
            'Logs & History',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFEC4899),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFEC4899),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Activity'),
            Tab(text: 'Statistics'),
            Tab(text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(),
          _buildStatisticsTab(),
          _buildSystemTab(),
        ],
      ),
    );
  }

  // ── Activity Tab ──────────────────────────────────────────────────────────
  Widget _buildActivityTab() {
    return Column(
      children: [
        // Filter chips
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filterOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final option = _filterOptions[index];
              final isSelected = _selectedFilter == option;
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _selectedFilter = option),
                backgroundColor: Colors.white,
                selectedColor:
                    const Color(0xFFEC4899).withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected
                      ? const Color(0xFFEC4899)
                      : Colors.grey,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFFEC4899)
                        : Colors.grey.shade300,
                  ),
                ),
              );
            },
          ),
        ),

        // Activity list
        Expanded(
          child: StreamBuilder<List<AlertModel>>(
            stream: _alertService.streamAlerts(
              limit: 50,
              collection: 'alerts',
              orderField: 'created_at',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Loading activity logs…',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Error loading alerts',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }

              final all = snapshot.data ?? [];
              final filtered =
                  all.where(_matchesFilter).toList();

              if (filtered.isEmpty) return _buildEmptyState();

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filtered.length,
                itemBuilder: (context, i) =>
                    _buildActivityCard(filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Activity card ─────────────────────────────────────────────────────────
  Widget _buildActivityCard(AlertModel alert) {
    final color = _getTypeColor(alert.type.toString());
    final icon = _getTypeIcon(alert.type.toString());
    final title = _formatType(alert.type.toString());
    final isFace = _isFaceAlert(alert.type.toString());
    final hasImage = isFace && alert.imageUrl.isNotEmpty;

    final lensText =
        alert.lens.isEmpty ? 'Unknown lens' : alert.lens;
    final location = alert.note.isEmpty
        ? 'Lens: $lensText'
        : 'Lens: $lensText • ${alert.note}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
            context, AppRoutes.alertDetail,
            arguments: alert),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Avatar: face image OR icon ──────────────────────
              _buildAvatar(
                hasImage: hasImage,
                imageUrl: alert.imageUrl,
                icon: icon,
                color: color,
                isFace: isFace,
              ),

              const SizedBox(width: 14),

              // ── Text info ────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        // Badge for face alerts
                        if (isFace)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Text(
                              hasImage ? 'PHOTO' : 'NO IMG',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: color,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(alert.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar widget ─────────────────────────────────────────────────────────
  Widget _buildAvatar({
    required bool hasImage,
    required String imageUrl,
    required IconData icon,
    required Color color,
    required bool isFace,
  }) {
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            headers: const {'Cache-Control': 'max-age=3600'},
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Image URL exists but failed to load
              return _styledPlaceholder(
                color: color,
                icon: Icons.broken_image_rounded,
                label: 'Error',
              );
            },
          ),
        ),
      );
    }

    // Face alert with no image stored
    if (isFace) {
      return _styledPlaceholder(
        color: color,
        icon: Icons.face_retouching_off_rounded,
        label: 'No\nPhoto',
      );
    }

    // Non-face alert icon
    return _iconAvatar(icon, color);
  }

  Widget _styledPlaceholder({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAvatar(IconData icon, Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }

  // ── Statistics Tab ────────────────────────────────────────────────────────
  Widget _buildStatisticsTab() {
    return StreamBuilder<List<AlertModel>>(
      stream: _alertService.streamAlerts(
        limit: 100,
        collection: 'alerts',
        orderField: 'created_at',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final alerts = snapshot.data ?? [];
        if (alerts.isEmpty) return _buildStatisticsPlaceholder();

        final fireCount = alerts
            .where((a) =>
                _normalizeType(a.type.toString()) == 'fire')
            .length;
        final smokeCount = alerts
            .where((a) =>
                _normalizeType(a.type.toString()) == 'smoke')
            .length;
        final unknownCount = alerts.where((a) {
          final t = _normalizeType(a.type.toString());
          return t == 'unknown_face' || t == 'unknownface';
        }).length;
        final motionCount = alerts
            .where((a) =>
                _normalizeType(a.type.toString()) == 'motion')
            .length;

        final today = DateTime.now();
        final todayAlerts = alerts
            .where((a) =>
                a.createdAt.year == today.year &&
                a.createdAt.month == today.month &&
                a.createdAt.day == today.day)
            .length;
        final yesterday =
            today.subtract(const Duration(days: 1));
        final yesterdayAlerts = alerts
            .where((a) =>
                a.createdAt.year == yesterday.year &&
                a.createdAt.month == yesterday.month &&
                a.createdAt.day == yesterday.day)
            .length;

        final faceWithImg = alerts
            .where((a) =>
                _isFaceAlert(a.type.toString()) &&
                a.imageUrl.isNotEmpty)
            .length;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _statSectionTitle('Overview'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Total Alerts',
                      alerts.length.toString(),
                      Icons.notifications_rounded,
                      const Color(0xFF8B5CF6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('Today',
                      todayAlerts.toString(),
                      Icons.today_rounded,
                      const Color(0xFF45B7D1)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Yesterday',
                      yesterdayAlerts.toString(),
                      Icons.calendar_today_rounded,
                      const Color(0xFF4ECDC4)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('Face Photos',
                      faceWithImg.toString(),
                      Icons.face_rounded,
                      const Color(0xFFEC4899)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _statSectionTitle('Detection Breakdown'),
            const SizedBox(height: 12),
            _buildStatCard('Fire Detected', fireCount.toString(),
                Icons.local_fire_department_rounded,
                const Color(0xFFFF6B6B)),
            const SizedBox(height: 12),
            _buildStatCard('Smoke Detected', smokeCount.toString(),
                Icons.cloud_rounded,
                const Color(0xFFF59E0B)),
            const SizedBox(height: 12),
            _buildStatCard('Unknown Persons',
                unknownCount.toString(),
                Icons.person_off_rounded,
                const Color(0xFFEC4899)),
            const SizedBox(height: 12),
            _buildStatCard('Motion Events', motionCount.toString(),
                Icons.directions_run_rounded,
                const Color(0xFF4ECDC4)),
          ],
        );
      },
    );
  }

  Widget _statSectionTitle(String t) => ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
        ).createShader(b),
        child: Text(t,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
      );

  Widget _buildStatisticsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                const Color(0xFF8B5CF6).withOpacity(0.1),
                const Color(0xFF06B6D4).withOpacity(0.1),
              ]),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                size: 64, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 24),
          const Text('No Data Available',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text('Statistics will appear once alerts are detected',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── System Tab ────────────────────────────────────────────────────────────
  Widget _buildSystemTab() {
    final systemLogs = [
      SystemLog(
        type: 'info',
        message: 'Robot 1 patrol completed successfully',
        time: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      SystemLog(
        type: 'warning',
        message: 'Low battery detected on Robot 3',
        time: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      SystemLog(
        type: 'success',
        message: 'System maintenance completed',
        time: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      SystemLog(
        type: 'error',
        message: 'Connection lost with Robot 2',
        time: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      SystemLog(
        type: 'info',
        message: 'Obstacle detected and avoided',
        time: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      SystemLog(
        type: 'success',
        message: 'All robots online and operational',
        time: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      SystemLog(
        type: 'info',
        message: 'Scheduled patrol route updated',
        time: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: systemLogs.length,
      itemBuilder: (_, i) => _buildSystemLogCard(systemLogs[i]),
    );
  }

  Widget _buildSystemLogCard(SystemLog log) {
    Color color;
    IconData icon;
    switch (log.type) {
      case 'error':
        color = const Color(0xFFFF6B6B);
        icon = Icons.error_rounded;
        break;
      case 'warning':
        color = const Color(0xFFF59E0B);
        icon = Icons.warning_rounded;
        break;
      case 'success':
        color = const Color(0xFF4ECDC4);
        icon = Icons.check_circle_rounded;
        break;
      default:
        color = const Color(0xFF45B7D1);
        icon = Icons.info_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.message,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text(timeago.format(log.time),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                const Color(0xFF06B6D4).withOpacity(0.1),
                const Color(0xFF8B5CF6).withOpacity(0.1),
              ]),
            ),
            child: const Icon(Icons.history_rounded,
                size: 64, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 24),
          const Text('No Activity Found',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'No alerts have been recorded yet'
                : 'No logs match your selected filter',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class SystemLog {
  final String type;
  final String message;
  final DateTime time;
  SystemLog(
      {required this.type,
      required this.message,
      required this.time});
}