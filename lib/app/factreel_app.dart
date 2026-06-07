import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_controller.dart';

import '../features/fact_feed/presentation/fact_feed_screen.dart';

class FactReelApp extends StatefulWidget {
  const FactReelApp({super.key});

  @override
  State<FactReelApp> createState() => _FactReelAppState();
}

class _FactReelAppState extends State<FactReelApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.load();
  }

  static const Color offWhite = Color(0xFFF7F5F2);
  static const Color ink = Color(0xFF111111);
  static const Color accent = Color(0xFFE84855);
  static const Color accent2 = Color(0xFFF5A623);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance,
      builder: (context, dark, child) {
        final brightness = dark ? Brightness.dark : Brightness.light;
        final baseTheme = ThemeData(
          useMaterial3: true,
          brightness: brightness,
          scaffoldBackgroundColor: dark ? ink : offWhite,
          colorScheme: dark
              ? const ColorScheme.dark(
                  surface: ink,
                  primary: accent,
                  secondary: accent2,
                  onSurface: offWhite,
                )
              : const ColorScheme.light(
                  surface: offWhite,
                  primary: accent,
                  secondary: accent2,
                  onSurface: ink,
                ),
        );

        final theme = baseTheme.copyWith(
          textTheme: GoogleFonts.dmSansTextTheme(baseTheme.textTheme),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FactReel – Did You Know?',
          theme: theme,
          home: const FactFeedScreen(),
        );
      },
    );
  }
}
