import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fact_feed/presentation/fact_feed_screen.dart';

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  String? _selectedCategory;
  bool _navigating = false;

  static const List<_CategoryItem> _categories = [
    _CategoryItem(
      key: 'science',
      label: 'Science',
      icon: Icons.science,
      color: Color(0xFFE84855),
      description: 'Chemistry, physics, biology & more',
    ),
    _CategoryItem(
      key: 'space',
      label: 'Space',
      icon: Icons.rocket_launch,
      color: Color(0xFF6C63FF),
      description: 'Stars, planets, galaxies & cosmos',
    ),
    _CategoryItem(
      key: 'animals',
      label: 'Animals',
      icon: Icons.pets,
      color: Color(0xFFF5A623),
      description: 'Wildlife, marine life & insects',
    ),
    _CategoryItem(
      key: 'history',
      label: 'History',
      icon: Icons.account_balance,
      color: Color(0xFF3BAD4C),
      description: 'Ancient civilizations & world events',
    ),
  ];

  void _onCategoryTap(String category) {
    setState(() => _selectedCategory = category);
  }

  Future<void> _onContinue() async {
    final category = _selectedCategory;
    if (category == null || _navigating) return;
    _navigating = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('factreel_category', category);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const FactFeedScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // Resolve the accent color of the selected category (for Continue button)
    final selectedInfo = _categories.firstWhere(
      (c) => c.key == _selectedCategory,
      orElse: () => _categories.first,
    );
    final continueColor =
        _selectedCategory != null ? selectedInfo.color : const Color(0xFFE84855);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24, safeTop + 40, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a Category',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick a topic to start exploring facts',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Category grid ────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat.key;
                  return _CategoryCard(
                    item: cat,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => _onCategoryTap(cat.key),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Bottom area ──────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, safeBottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hint text
                Center(
                  child: Text(
                    'You can change this later in Settings',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF888888),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    child: ElevatedButton(
                      onPressed: _selectedCategory != null ? _onContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedCategory != null
                            ? continueColor
                            : (isDark
                                ? const Color(0xFF2C2C2C)
                                : const Color(0xFFE0E0E0)),
                        disabledBackgroundColor: isDark
                            ? const Color(0xFF2C2C2C)
                            : const Color(0xFFE0E0E0),
                        foregroundColor: Colors.white,
                        disabledForegroundColor:
                            const Color(0xFF888888),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _selectedCategory != null
                            ? 'Continue'
                            : 'Select a Category',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
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

class _CategoryItem {
  const _CategoryItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String description;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final _CategoryItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? item.color : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? item.color.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 24 : 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: isSelected ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.icon,
                size: 24,
                color: item.color,
              ),
            ),
            const Spacer(),
            // Label
            Text(
              item.label,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111111),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            // Description
            Text(
              item.description,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF888888),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
