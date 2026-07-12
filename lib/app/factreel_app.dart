import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_controller.dart';

import 'app_router.dart';

class FactReelApp extends ConsumerWidget {
  const FactReelApp({super.key});

  static const Color offWhite = Color(0xFFF7F5F2);
  static const Color ink = Color(0xFF111111);
  static const Color accent = Color(0xFFE84855);
  static const Color accent2 = Color(0xFFF5A623);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(themeProvider);
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
          home: const AppRouter(),
        );
  }
}
