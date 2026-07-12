import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme_controller.dart';
import '../models/fact_card_state.dart';
import 'providers/feed_provider.dart';
import 'widgets/fact_card.dart';
import 'widgets/fact_error_card.dart';
import 'widgets/fact_install_banner.dart';
import 'widgets/fact_skeleton_card.dart';
import 'liked_screen.dart';
import 'settings_screen.dart';

class FactFeedScreen extends ConsumerStatefulWidget {
  const FactFeedScreen({super.key});

  @override
  ConsumerState<FactFeedScreen> createState() => _FactFeedScreenState();
}

class _FactFeedScreenState extends ConsumerState<FactFeedScreen> {
  final PageController _pageController = PageController();

  int _currentTab = 0;
  bool _showScrollHint = true;
  double _progress = 0;
  String? _toastMessage;
  Timer? _toastTimer;
  Timer? _installTimer;
  bool _showInstallBanner = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(feedProvider.notifier).bootstrap());
    if (kIsWeb) {
      _installTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _showInstallBanner = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _toastTimer?.cancel();
    _installTimer?.cancel();
    super.dispose();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _toastMessage = null);
      }
    });
  }

  void _updateProgress() {
    if (!_pageController.hasClients) {
      return;
    }

    final position = _pageController.position;
    final max = position.maxScrollExtent;
    final offset = position.pixels;
    final progress = max <= 0 ? 0.0 : (offset / max).clamp(0.0, 1.0);
    final showHint = offset <= 80;

    if (progress != _progress || showHint != _showScrollHint) {
      setState(() {
        _progress = progress;
        _showScrollHint = showHint;
      });
    }

    final currentPage = (_pageController.page ?? 0).round();
    final feedState = ref.read(feedProvider);
    if (currentPage >= feedState.items.length - 2) {
      ref.read(feedProvider.notifier).loadBatch(count: FeedNotifier.nextBatchSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final feedState = ref.watch(feedProvider);
    Widget tabContent;
    if (_currentTab == 0) {
      tabContent = LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= 480;
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _updateProgress();
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const PageScrollPhysics(),
              itemCount: feedState.items.length,
              onPageChanged: (page) {
                _updateProgress();
                if (page >= 0 && page < feedState.items.length) {
                  unawaited(ref.read(feedProvider.notifier).markFactViewed(feedState.items[page].id));
                }
              },
              itemBuilder: (context, index) {
                final item = feedState.items[index];
                return _FeedPage(
                  index: index,
                  compact: compact,
                  language: feedState.language,
                  item: item,
                  onRetry: () => ref.read(feedProvider.notifier).retryCard(index),
                  onCopy: (text) async {
                    await Clipboard.setData(ClipboardData(text: text));
                    ref.read(feedProvider.notifier).setItemCopied(index, true);
                    _showToast('Copied to clipboard!');
                    Future<void>.delayed(const Duration(seconds: 2), () {
                      if (mounted && index < ref.read(feedProvider).items.length) {
                        ref.read(feedProvider.notifier).setItemCopied(index, false);
                      }
                    });
                  },
                  onShare: (text) async {
                    await SharePlus.instance.share(
                      ShareParams(
                        text: '💡 $text\n\n— FactReel',
                        subject: 'Did You Know?',
                      ),
                    );
                  },
                  onLike: () => ref.read(feedProvider.notifier).toggleLikeAt(index),
                );
              },
            ),
          );
        },
      );
    } else if (_currentTab == 1) {
      tabContent = LikedScreen(
        items: feedState.items
            .where((i) => i.liked && i.status == FactCardStatus.loaded)
            .toList(),
        onRemove: (id) => ref.read(feedProvider.notifier).removeLikeById(id),
      );
    } else {
      tabContent = SettingsScreen(
        darkModeEnabled: isDark,
        onToggleDarkMode: (enabled) => ref.read(themeProvider.notifier).setDark(enabled),
        currentCategory: feedState.currentCategory,
        onCategoryChanged: (cat) => ref.read(feedProvider.notifier).reloadForCategory(cat),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: isDark ? const Color(0xFF111111) : const Color(0xFFF7F5F2),
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            tabContent,
            _TopBar(
              safeTop: MediaQuery.of(context).padding.top,
              language: feedState.language,
              onLanguageSelected: (lang) => ref.read(feedProvider.notifier).setLanguage(lang),
            ),
            if (_currentTab == 0) ...[
              _StatsStrip(
                safeTop: MediaQuery.of(context).padding.top,
                dailyStreak: feedState.dailyStreak,
                factsRead: feedState.factsReadTotal,
                goalCompletedToday: feedState.goalCompletedToday,
                dailyGoal: FeedNotifier.dailyGoal,
              ),
              _ProgressBar(progress: _progress),
              _ScrollHint(visible: _showScrollHint),
            ],
            if (_toastMessage != null) _Toast(message: _toastMessage!),
            if (_showInstallBanner)
              FactInstallBanner(
                onInstall: () =>
                    _showToast('Install not available in native app'),
                onDismiss: () => setState(() => _showInstallBanner = false),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 78,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home,
                    label: 'Home',
                    active: _currentTab == 0,
                    onTap: () => setState(() => _currentTab = 0),
                  ),
                  _NavItem(
                    icon: Icons.favorite_border,
                    label: 'Liked',
                    active: _currentTab == 1,
                    onTap: () => setState(() => _currentTab = 1),
                  ),
                  _NavItem(
                    icon: Icons.settings,
                    label: 'Settings',
                    active: _currentTab == 2,
                    onTap: () => setState(() => _currentTab = 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedPage extends StatelessWidget {
  const _FeedPage({
    required this.index,
    required this.compact,
    required this.language,
    required this.item,
    required this.onRetry,
    required this.onCopy,
    required this.onShare,
    required this.onLike,
  });

  final int index;
  final bool compact;
  final String language;
  final FactCardState item;
  final VoidCallback onRetry;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onShare;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return switch (item.status) {
      FactCardStatus.loading => const FactSkeletonCard(),
      FactCardStatus.error => FactErrorCard(onRetry: onRetry),
      FactCardStatus.loaded => SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: FactCard(
                index: index,
                compact: compact,
                language: language,
                item: item,
                onCopy: onCopy,
                onShare: onShare,
                onLike: onLike,
              ),
            ),
          ],
        ),
      ),
    };
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 3,
          width: MediaQuery.sizeOf(context).width * progress,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Color(0xFFE84855), Color(0xFFF5A623)],
            ),
            borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.safeTop,
    required this.dailyStreak,
    required this.factsRead,
    required this.goalCompletedToday,
    required this.dailyGoal,
  });

  final double safeTop;
  final int dailyStreak;
  final int factsRead;
  final int goalCompletedToday;
  final int dailyGoal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: safeTop + 72,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(50),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatItem(
                icon: Icons.local_fire_department,
                value: '$dailyStreak',
                color: const Color(0xFFE84855),
                onTap: () => _showExpandedStat(context, 1, 'Daily Streak', '$dailyStreak Days', const Color(0xFFE84855), 'Read $dailyGoal facts daily to keep your streak alive and build a strong learning habit!'),
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 12, color: const Color.fromRGBO(0, 0, 0, 0.08)),
              const SizedBox(width: 10),
              _StatItem(
                icon: Icons.emoji_events,
                value: '$factsRead',
                color: const Color(0xFFF5A623),
                onTap: () => _showExpandedStat(context, 2, 'Total Facts Read', '$factsRead', const Color(0xFFF5A623), 'This is the total number of facts you have discovered and read since you started using the app.'),
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 12, color: const Color.fromRGBO(0, 0, 0, 0.08)),
              const SizedBox(width: 10),
              _StatItem(
                icon: goalCompletedToday >= dailyGoal ? Icons.check_circle : Icons.flag,
                value: '$goalCompletedToday/$dailyGoal',
                color: goalCompletedToday >= dailyGoal ? const Color(0xFF3BAD4C) : const Color(0xFF888888),
                onTap: () => _showExpandedStat(context, 3, 'Daily Goal', '$goalCompletedToday / $dailyGoal', goalCompletedToday >= dailyGoal ? const Color(0xFF3BAD4C) : const Color(0xFF888888), 'Reach your daily goal of reading $dailyGoal facts to increase your streak!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpandedStat(BuildContext context, int type, String title, String value, Color color, String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(type == 1 ? Icons.local_fire_department : type == 2 ? Icons.emoji_events : Icons.check_circle, size: 40, color: color),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: GoogleFonts.dmSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: const Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F5F2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Close',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111111),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111111),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollHint extends StatelessWidget {
  const _ScrollHint({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scroll',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: const Color(0xFF888888),
                ),
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1600),
                builder: (context, value, child) {
                  final bounce = (value <= 0.5 ? value : 1 - value) * 12;
                  return Transform.translate(
                    offset: Offset(0, bounce),
                    child: child,
                  );
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 90,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.safeTop,
    required this.language,
    required this.onLanguageSelected,
  });

  final double safeTop;
  final String language;
  final ValueChanged<String> onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, safeTop + 14, 20, 10),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF111111) : const Color(0xFFF7F5F2)).withValues(alpha: 0.92),
              border: Border(
                bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color.fromRGBO(0, 0, 0, 0.06)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF111111),
                    ),
                    children: const <TextSpan>[
                      TextSpan(text: 'Fact'),
                      TextSpan(
                        text: 'Reel',
                        style: TextStyle(color: Color(0xFFE84855)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color.fromRGBO(0, 0, 0, 0.06),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LangButton(
                        label: 'English',
                        active: language == 'en',
                        onTap: () => onLanguageSelected('en'),
                      ),
                      const SizedBox(width: 6),
                      _LangButton(
                        label: 'हिन्दी',
                        active: language == 'hi',
                        onTap: () => onLanguageSelected('hi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: active ? (isDark ? const Color(0xFF333333) : Colors.white) : Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        boxShadow: active && !isDark
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active
                    ? (isDark ? Colors.white : const Color(0xFF111111))
                    : const Color(0xFF888888),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active ? const Color(0xFFE84855) : (isDark ? const Color(0xFF888888) : const Color(0xFF444444));
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
