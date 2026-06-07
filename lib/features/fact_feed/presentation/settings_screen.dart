import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.darkModeEnabled,
    required this.onToggleDarkMode,
  });

  final bool darkModeEnabled;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, safeTop + 80, 20, 20),
      children: [
        SwitchListTile(
          title: Text(
            'Dark Mode',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'Toggle dark theme',
            style: GoogleFonts.dmSans(color: const Color(0xFF888888)),
          ),
          value: ThemeController.instance.value,
          onChanged: (v) => ThemeController.instance.setDark(v),
        ),
        const SizedBox(height: 8),
        ListTile(
          title: Text(
            'Share App',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          onTap: () => Share.share('Check out FactReel — did you know?'),
          trailing: Icon(
            Icons.share,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          title: Text(
            'Rate App',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          onTap: () {},
          trailing: Icon(
            Icons.star_border,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/app_icon.png',
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.info_outline, size: 40),
            ),
          ),
          title: Text(
            'About',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'FactReel — Did You Know?\nVersion 1.0',
            style: GoogleFonts.dmSans(color: const Color(0xFF888888)),
          ),
          onTap: () {},
        ),
      ],
    );
  }
}
