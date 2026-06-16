import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/category_selection_screen.dart';
import '../features/fact_feed/presentation/fact_feed_screen.dart';

/// Determines which screen to show based on onboarding/category state.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _determineRoute();
  }

  Future<void> _determineRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('factreel_onboarding_done') ?? false;
    final category = prefs.getString('factreel_category');

    if (!mounted) return;

    Widget screen;
    if (!onboardingDone) {
      screen = const OnboardingScreen();
    } else if (category == null || category.isEmpty) {
      screen = const CategorySelectionScreen();
    } else {
      screen = const FactFeedScreen();
    }

    setState(() => _initialScreen = screen);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialScreen == null) {
      // Brief splash while determining route
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF111111) : const Color(0xFFF7F5F2),
        body: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFFE84855)),
            ),
          ),
        ),
      );
    }

    return _initialScreen!;
  }
}
