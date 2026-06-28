import 'package:flutter/material.dart';

class VisionBotAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String pageTitle;
  final String? pageSubtitle;
  @deprecated
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color backgroundColor;
  final double elevation;
  final bool centerTitle;

  const VisionBotAppBar({
    super.key,
    required this.pageTitle,
    this.pageSubtitle,
    this.subtitle,
    this.leading,
    this.actions,
    this.bottom,
    this.backgroundColor = Colors.white,
    this.elevation = 0,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final String? effectiveSubtitle =
        pageSubtitle ?? subtitle;

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: elevation,
      centerTitle: false,

      leading: leading,
      actions: actions,
      bottom: bottom,

      title: Row(
        children: [

          // LOGO LEFT TOP CORNER
          Image.asset(
            'assets/logobg.png',
            height: 42,
            width: 42,
            fit: BoxFit.contain,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [

                ShaderMask(
                  shaderCallback: (bounds) =>
                      const LinearGradient(
                    colors: [
                      Color(0xFFEC4899),
                      Color(0xFF06B6D4),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'VisionBot',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),

                if (pageTitle.isNotEmpty)
                  Text(
                    pageTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),

                if (effectiveSubtitle?.isNotEmpty ?? false)
                  Text(
                    effectiveSubtitle!,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}