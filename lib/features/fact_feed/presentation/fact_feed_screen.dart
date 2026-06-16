import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme_controller.dart';
import '../../fact_feed/data/fact_service.dart';
import '../models/fact_card_state.dart';
import 'widgets/fact_card.dart';
import 'widgets/fact_error_card.dart';
import 'widgets/fact_install_banner.dart';
import 'widgets/fact_skeleton_card.dart';
import 'liked_screen.dart';
import 'settings_screen.dart';

class FactFeedScreen extends StatefulWidget {
  const FactFeedScreen({super.key});

  @override
  State<FactFeedScreen> createState() => _FactFeedScreenState();
}

class _FactFeedScreenState extends State<FactFeedScreen> {
  static const int _initialBatchSize = 10;
  static const int _nextBatchSize = 5;

  final FactService _factService = FactService();
  final PageController _pageController = PageController();
  final List<FactCardState> _items = <FactCardState>[];
  final Set<String> _seenIds = <String>{};

  int _currentTab = 0;
  final Set<String> _likedIds = <String>{};
  final Set<String> _sessionViewedIds = <String>{};

  String _language = 'en';
  bool _loadingMore = false;
  bool _showScrollHint = true;
  double _progress = 0;
  int _factCounter = 0;
  int _dailyStreak = 0;
  int _factsReadTotal = 0;
  int _goalCompletedToday = 0;
  static const int _dailyGoal = 50;
  int _translationToken = 0;
  final Map<String, String> _translationCache = <String, String>{};
  String? _toastMessage;
  Timer? _toastTimer;
  Timer? _installTimer;
  bool _showInstallBanner = false;
  String _currentCategory = 'science';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _toastTimer?.cancel();
    _installTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('factreel_lang') ?? 'en';
    _currentCategory = prefs.getString('factreel_category') ?? 'science';
    final likedList = prefs.getStringList('factreel_liked') ?? <String>[];
    _likedIds.addAll(likedList);
    _factsReadTotal = prefs.getInt('factreel_facts_read_total') ??
        (prefs.getStringList('factreel_viewed_ids')?.length ?? 0);

    final today = _todayKey();
    final savedStreak = prefs.getInt('factreel_streak_days') ?? 0;

    final lastStreakDateStr = prefs.getString('factreel_last_streak_date');
    final lastStreakDate = _parseDate(lastStreakDateStr);

    if (lastStreakDate != null && today.difference(lastStreakDate).inDays > 1) {
      _dailyStreak = 0;
      await prefs.setInt('factreel_streak_days', 0);
    } else {
      _dailyStreak = savedStreak;
    }

    final goalDate = prefs.getString('factreel_goal_date');
    if (goalDate == today.toIso8601String()) {
      _goalCompletedToday = prefs.getInt('factreel_goal_completed_today') ?? 0;
      if (_goalCompletedToday > _dailyGoal) {
        _goalCompletedToday = _dailyGoal;
      }
    } else {
      _goalCompletedToday = 0;
      await prefs.setString('factreel_goal_date', today.toIso8601String());
      await prefs.setInt('factreel_goal_completed_today', 0);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (kIsWeb) {
        _installTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _showInstallBanner = true);
          }
        });
      }
    });

    await _factService.loadFacts(_currentCategory);
    _loadBatch(count: _initialBatchSize);
    if (_items.isNotEmpty && _items.first.status == FactCardStatus.loaded) {
      await _markFactViewed(_items.first);
    }
  }

  Future<void> _reloadForCategory(String newCategory) async {
    if (newCategory == _currentCategory) return;
    _currentCategory = newCategory;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('factreel_category', newCategory);
    await _factService.loadFacts(newCategory);
    if (!mounted) return;
    setState(() {
      _items.clear();
      _factCounter = 0;
      _seenIds.clear();
      _loadingMore = false;
      _progress = 0;
      _showScrollHint = true;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _loadBatch(count: _initialBatchSize);
    if (_items.isNotEmpty && _items.first.status == FactCardStatus.loaded) {
      await _markFactViewed(_items.first);
    }
  }

  DateTime _todayKey() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      final parsed = DateTime.parse(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistLikesAndSaves() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('factreel_liked', _likedIds.toList());
  }

  Future<void> _persistUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('factreel_facts_read_total', _factsReadTotal);
    await prefs.setInt('factreel_streak_days', _dailyStreak);
    await prefs.setInt('factreel_goal_completed_today', _goalCompletedToday);
    await prefs.setString('factreel_goal_date', _todayKey().toIso8601String());
  }

  Future<void> _markFactViewed(FactCardState item) async {
    if (item.status != FactCardStatus.loaded || _sessionViewedIds.contains(item.id)) {
      return;
    }

    bool goalReachedThisTime = false;
    setState(() {
      _sessionViewedIds.add(item.id);
      _factsReadTotal = _factsReadTotal + 1;
      if (_goalCompletedToday < _dailyGoal) {
        _goalCompletedToday = _goalCompletedToday + 1;
        if (_goalCompletedToday == _dailyGoal) {
          goalReachedThisTime = true;
        }
      }
    });

    if (goalReachedThisTime) {
      final prefs = await SharedPreferences.getInstance();
      final now = _todayKey();
      final lastStreakDateStr = prefs.getString('factreel_last_streak_date');
      final lastStreakDate = _parseDate(lastStreakDateStr);
      
      if (lastStreakDate == null || now.difference(lastStreakDate).inDays > 0) {
        setState(() {
          _dailyStreak += 1;
        });
        await prefs.setInt('factreel_streak_days', _dailyStreak);
        await prefs.setString('factreel_last_streak_date', now.toIso8601String());
      }
    }

    await _persistUsageStats();
  }

  void _toggleLikeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    final current = _items[index];
    final newState = current.copyWith(liked: !current.liked);
    setState(() {
      _items[index] = newState;
      if (newState.liked) {
        _likedIds.add(newState.id);
      } else {
        _likedIds.remove(newState.id);
      }
    });
    _persistLikesAndSaves();
  }

  Future<void> _setLanguage(String language) async {
    if (_language == language) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('factreel_lang', language);

    setState(() {
      _language = language;
      _translationToken += 1;
    });

    if (language == 'en') {
      // Clear translations so raw English is shown immediately
      setState(() {
        for (var index = 0; index < _items.length; index += 1) {
          final item = _items[index];
          if (item.status == FactCardStatus.loaded) {
            _items[index] = item.copyWith(
              translatedText: null,
              translating: false,
            );
          }
        }
      });
      return;
    }

    // Hindi selected — translate all currently loaded facts
    final token = _translationToken;
    final loadedIndexes = <int>[];
    for (var index = 0; index < _items.length; index += 1) {
      if (_items[index].status == FactCardStatus.loaded) {
        loadedIndexes.add(index);
      }
    }

    setState(() {
      for (final index in loadedIndexes) {
        _items[index] = _items[index].copyWith(translating: true);
      }
    });

    for (final index in loadedIndexes) {
      if (!mounted || token != _translationToken || _language != 'hi') {
        return;
      }

      final item = _items[index];
      final rawText = item.rawText;
      if (rawText == null) continue;

      final cached = _translationCache[item.id];
      final translated =
          cached ?? await _factService.translateToHindi(rawText);
      if (cached == null) _translationCache[item.id] = translated;

      if (!mounted || token != _translationToken || _language != 'hi') {
        return;
      }

      setState(() {
        _items[index] = _items[index].copyWith(
          translatedText: translated,
          translating: false,
        );
      });
    }
  }

  void _loadBatch({required int count}) {
    if (_loadingMore || !_factService.isLoaded) {
      return;
    }

    _loadingMore = true;

    final newItems = <FactCardState>[];
    for (var index = 0; index < count; index += 1) {
      final fact = _factService.getNextFact(seenIds: _seenIds);
      _factCounter += 1;
      _seenIds.add(fact.id);
      final liked = _likedIds.contains(fact.id);
      newItems.add(
        FactCardState(
          id: fact.id,
          status: FactCardStatus.loaded,
          number: _factCounter,
          rawText: fact.text,
          liked: liked,
        ),
      );
    }

    setState(() => _items.addAll(newItems));
    _loadingMore = false;

    // Translate batch if Hindi is active
    if (_language == 'hi') {
      _translateItems(newItems.map((e) => _items.indexOf(e)).toList());
    }
  }

  /// Translates items at the given indexes to Hindi, using cache where possible.
  Future<void> _translateItems(List<int> indexes) async {
    final token = _translationToken;
    for (final index in indexes) {
      if (!mounted || token != _translationToken || _language != 'hi') return;
      if (index < 0 || index >= _items.length) continue;
      final item = _items[index];
      if (item.status != FactCardStatus.loaded || item.rawText == null) continue;

      // Mark as translating
      setState(() {
        _items[index] = item.copyWith(translating: true);
      });

      final cached = _translationCache[item.id];
      final translated =
          cached ?? await _factService.translateToHindi(item.rawText!);
      if (cached == null) _translationCache[item.id] = translated;

      if (!mounted || token != _translationToken || _language != 'hi') return;

      setState(() {
        if (index < _items.length) {
          _items[index] = _items[index].copyWith(
            translatedText: translated,
            translating: false,
          );
        }
      });
    }
  }

  void _retryCard(int index) {
    if (!_factService.isLoaded) return;
    final fact = _factService.getNextFact(seenIds: _seenIds);
    _factCounter += 1;
    _seenIds.add(fact.id);
    setState(() {
      _items[index] = FactCardState(
        id: fact.id,
        status: FactCardStatus.loaded,
        number: _factCounter,
        rawText: fact.text,
      );
    });
    // Translate if Hindi is active
    if (_language == 'hi') {
      _translateItems([index]);
    }
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
    if (currentPage >= _items.length - 2) {
      _loadBatch(count: _nextBatchSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              itemCount: _items.length,
              onPageChanged: (page) {
                _updateProgress();
                if (page >= 0 && page < _items.length) {
                  unawaited(_markFactViewed(_items[page]));
                }
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return _FeedPage(
                  index: index,
                  compact: compact,
                  language: _language,
                  item: item,
                  onRetry: () => _retryCard(index),
                  onCopy: (text) async {
                    await Clipboard.setData(ClipboardData(text: text));
                    setState(() {
                      _items[index] = _items[index].copyWith(copied: true);
                    });
                    _showToast('Copied to clipboard!');
                    Future<void>.delayed(const Duration(seconds: 2), () {
                      if (mounted && index < _items.length) {
                        setState(() {
                          _items[index] = _items[index].copyWith(
                            copied: false,
                          );
                        });
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
                  onLike: () => _toggleLikeAt(index),
                );
              },
            ),
          );
        },
      );
    } else if (_currentTab == 1) {
      tabContent = LikedScreen(
        items: _items
            .where((i) => i.liked && i.status == FactCardStatus.loaded)
            .toList(),
        onRemove: (id) {
          final index = _items.indexWhere((e) => e.id == id);
          if (index != -1) _toggleLikeAt(index);
        },
      );
    } else {
      tabContent = SettingsScreen(
        darkModeEnabled: isDark,
        onToggleDarkMode: (enabled) => ThemeController.instance.setDark(enabled),
        currentCategory: _currentCategory,
        onCategoryChanged: _reloadForCategory,
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
              language: _language,
              onLanguageSelected: _setLanguage,
            ),
            if (_currentTab == 0) ...[
              _StatsStrip(
                safeTop: MediaQuery.of(context).padding.top,
                dailyStreak: _dailyStreak,
                factsRead: _factsReadTotal,
                goalCompletedToday: _goalCompletedToday,
                dailyGoal: _dailyGoal,
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
