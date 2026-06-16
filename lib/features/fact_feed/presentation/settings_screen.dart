import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.darkModeEnabled,
    required this.onToggleDarkMode,
    required this.currentCategory,
    required this.onCategoryChanged,
  });

  final bool darkModeEnabled;
  final ValueChanged<bool> onToggleDarkMode;
  final String currentCategory;
  final ValueChanged<String> onCategoryChanged;

  static const Map<String, _CategoryInfo> _categories = {
    'science': _CategoryInfo('Science', Icons.science, Color(0xFFE84855)),
    'space': _CategoryInfo('Space', Icons.rocket_launch, Color(0xFF6C63FF)),
    'animals': _CategoryInfo('Animals', Icons.pets, Color(0xFFF5A623)),
    'history': _CategoryInfo('History', Icons.account_balance, Color(0xFF3BAD4C)),
  };

  String get _categoryLabel =>
      _categories[currentCategory]?.label ?? 'Science';

  void _showCategoryPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Choose Category',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Facts will load from the selected category',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 20),
                ..._categories.entries.map((entry) {
                  final key = entry.key;
                  final info = entry.value;
                  final isActive = key == currentCategory;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).pop();
                          if (key != currentCategory) {
                            onCategoryChanged(key);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? info.color.withValues(alpha: 0.10)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.03)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? info.color.withValues(alpha: 0.4)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: info.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  info.icon,
                                  size: 22,
                                  color: info.color,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  info.label,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF111111),
                                  ),
                                ),
                              ),
                              if (isActive)
                                Icon(
                                  Icons.check_circle,
                                  size: 22,
                                  color: info.color,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

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
            'Category',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            _categoryLabel,
            style: GoogleFonts.dmSans(color: const Color(0xFF888888)),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onTap: () => _showCategoryPicker(context),
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

class _CategoryInfo {
  const _CategoryInfo(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
