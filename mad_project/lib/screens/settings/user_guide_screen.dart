import 'package:flutter/material.dart';

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _selectedCategory = 0;

  final List<GuideCategory> _categories = [
    GuideCategory(
      title: 'Getting Started',
      icon: Icons.rocket_launch_rounded,
      color: const Color(0xFF06B6D4),
    ),
    GuideCategory(
      title: 'Features',
      icon: Icons.star_rounded,
      color: const Color(0xFFEC4899),
    ),
    GuideCategory(
      title: 'Alerts',
      icon: Icons.notification_important_rounded,
      color: const Color(0xFFFF6B6B),
    ),
    GuideCategory(
      title: 'Troubleshooting',
      icon: Icons.build_rounded,
      color: const Color(0xFF8B5CF6),
    ),
  ];

  final Map<int, List<GuideSection>> _guides = {
    0: [
      // Getting Started
      GuideSection(
        title: 'Welcome to Vision Bot',
        description:
            'Vision Bot is an AI-powered surveillance system that helps you monitor your property with intelligent robots.',
        steps: [
          'Create your account with email or Google',
          'Verify your email address',
          'Select your role (Admin or Security Officer)',
          'Complete your profile setup',
        ],
        icon: Icons.waving_hand_rounded,
      ),
      GuideSection(
        title: 'Dashboard Overview',
        description:
            'The dashboard is your command center, showing real-time system status and key metrics.',
        steps: [
          'View active alerts at the top',
          'Check robot status and battery levels',
          'Monitor coverage area statistics',
          'Access quick actions for common tasks',
        ],
        icon: Icons.dashboard_rounded,
      ),
      GuideSection(
        title: 'Navigation',
        description:
            'Easily navigate through the app using the bottom navigation bar.',
        steps: [
          'Home - Main dashboard and system overview',
          'Alerts - View and manage all security alerts',
          'Gallery - Browse captured images',
          'Profile - Manage your account settings',
        ],
        icon: Icons.menu_rounded,
      ),
    ],
    1: [
      // Features
      GuideSection(
        title: 'Real-Time Monitoring',
        description:
            'Monitor your property in real-time with multiple robots working simultaneously.',
        steps: [
          'View live robot locations on GPS map',
          'Check robot battery and status',
          'Track patrol routes and coverage',
          'Receive instant alerts for anomalies',
        ],
        icon: Icons.visibility_rounded,
      ),
      GuideSection(
        title: 'Alert System',
        description:
            'Get notified immediately when the system detects potential threats or anomalies.',
        steps: [
          'Fire detection - Immediate critical alerts',
          'Smoke detection - Warning notifications',
          'Motion detection - Activity monitoring',
          'Unauthorized access - Security alerts',
        ],
        icon: Icons.notifications_active_rounded,
      ),
      GuideSection(
        title: 'GPS Tracking',
        description:
            'Track all robots in real-time with precise GPS coordinates.',
        steps: [
          'Open GPS Tracking from dashboard',
          'View all robots on interactive map',
          'Tap robot card to focus on location',
          'Monitor robot battery and status',
        ],
        icon: Icons.location_on_rounded,
      ),
      GuideSection(
        title: 'Image Gallery',
        description:
            'Access and review all captured images from robot cameras.',
        steps: [
          'Browse images in grid view',
          'Tap to view details',
          'Share or export images as needed',
        ],
        icon: Icons.photo_library_rounded,
      ),
    ],
    2: [
      // Alerts
      GuideSection(
        title: 'Understanding Alert Types',
        description:
            'Different alerts indicate various security situations requiring attention.',
        steps: [
          'Fire Alert (Critical) - Immediate action required',
          'Smoke Alert (Warning) - Potential fire hazard',
          'Human Detection - Unauthorized person detected',
          'Motion Alert - Movement in monitored area',
          'Restricted Area - Entry to prohibited zone',
        ],
        icon: Icons.warning_amber_rounded,
      ),
      GuideSection(
        title: 'Managing Alerts',
        description:
            'Learn how to effectively respond to and manage security alerts.',
        steps: [
          'Tap on alert to view full details',
          'Review captured image evidence',
          'Check exact location and timestamp',
          'Mark as read after reviewing',
          'Take appropriate action if needed',
        ],
        icon: Icons.task_alt_rounded,
      ),
      GuideSection(
        title: 'Alert Notifications',
        description:
            'Customize how you receive alert notifications on your device.',
        steps: [
          'Go to Settings > Notifications',
          'Enable/disable notification types',
          'Set sound and vibration preferences',
          'Configure quiet hours if needed',
        ],
        icon: Icons.settings_rounded,
      ),
    ],
    3: [
      // Troubleshooting
      GuideSection(
        title: 'Common Issues',
        description: 'Quick solutions for frequently encountered problems.',
        steps: [
          'Not receiving alerts? Check notification settings',
          'GPS not working? Enable location permissions',
          'Login issues? Try password reset',
          'App slow? Clear cache and restart',
        ],
        icon: Icons.help_outline_rounded,
      ),
      GuideSection(
        title: 'Account & Security',
        description:
            'Manage your account security and recover access if needed.',
        steps: [
          'Change password regularly in Profile settings',
          'Enable two-factor authentication',
          'Use "Forgot Password" if locked out',
          'Contact support for account issues',
        ],
        icon: Icons.security_rounded,
      ),
      GuideSection(
        title: 'System Requirements',
        description:
            'Ensure your device meets the minimum requirements for optimal performance.',
        steps: [
          'Android 6.0+ or iOS 12.0+',
          'Stable internet connection required',
          'Location services for GPS tracking',
          'Camera permission for QR scanning',
        ],
        icon: Icons.phonelink_setup_rounded,
      ),
      GuideSection(
        title: 'Get Help',
        description: 'Still need assistance? We\'re here to help!',
        steps: [
          'Email: support@visionbot.com',
          'Phone: +1 (555) 123-4567',
          'Website: www.visionbot.com/support',
          'Live Chat: Available 24/7 in app',
        ],
        icon: Icons.contact_support_rounded,
      ),
    ],
  };

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
            'User Guide',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Category Tabs
            Container(
              height: 80,
              color: Colors.white,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildCategoryTab(index);
                },
              ),
            ),

            // Guide Content
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _guides[_selectedCategory]?.length ?? 0,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  return _buildGuideCard(_guides[_selectedCategory]![index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(int index) {
    final category = _categories[index];
    final isSelected = _selectedCategory == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [category.color, category.color.withOpacity(0.7)],
                  )
                : null,
            color: isSelected ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: category.color.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                category.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard(GuideSection section) {
    final categoryColor = _categories[_selectedCategory].color;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  categoryColor.withOpacity(0.1),
                  categoryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [categoryColor, categoryColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: categoryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(section.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.description,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),

                // Steps
                ...section.steps.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                categoryColor,
                                categoryColor.withOpacity(0.7),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GuideCategory {
  final String title;
  final IconData icon;
  final Color color;

  GuideCategory({required this.title, required this.icon, required this.color});
}

class GuideSection {
  final String title;
  final String description;
  final List<String> steps;
  final IconData icon;

  GuideSection({
    required this.title,
    required this.description,
    required this.steps,
    required this.icon,
  });
}
