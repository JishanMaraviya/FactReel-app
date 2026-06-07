import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/fact_card_state.dart';

class FactCard extends StatelessWidget {
  const FactCard({
    super.key,
    required this.index,
    required this.compact,
    required this.language,
    required this.item,
    required this.onCopy,
    required this.onShare,
    required this.onLike,
  });

  final int index;
  final bool compact;
  final String language;
  final FactCardState item;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onShare;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final cardPadding = compact
        ? const EdgeInsets.fromLTRB(22, 28, 22, 22)
        : const EdgeInsets.fromLTRB(32, 36, 32, 28);
    final radius = compact ? 22.0 : 28.0;
    final bodySize = compact ? 17.6 : 19.0;

    return Container(
      height: double.infinity,
      padding: EdgeInsets.fromLTRB(20, safeTop + 130, 20, 30),
      child: Stack(
        children: [
          Positioned.fill(child: _Backdrop(index: index)),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.97, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final opacity = ((value - 0.97) / 0.03).clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 30),
                    child: Transform.scale(scale: value, child: child),
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 60,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  padding: cardPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(232, 72, 85, 0.08),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              'Did You Know?',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: const Color(0xFFE84855),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#${item.number ?? index + 1}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF888888),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AnimatedOpacity(
                        opacity: item.translating ? 0.4 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          item.displayText,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: bodySize,
                            fontWeight: FontWeight.w700,
                            height: 1.55,
                            color: const Color(0xFF111111),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _LangDot(),
                          const SizedBox(width: 6),
                          Text(
                            language == 'hi' ? 'हिन्दी' : 'English',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: const Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 1,
                        color: const Color.fromRGBO(0, 0, 0, 0.06),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _ActionButton(
                                icon: _SvgAssets.copy,
                                label: item.copied ? 'Copied!' : 'Copy',
                                active: item.copied,
                                activeBackground: const Color.fromRGBO(
                                  59,
                                  173,
                                  76,
                                  0.12,
                                ),
                                activeForeground: const Color(0xFF3BAD4C),
                                onTap: () => onCopy(item.displayText),
                              ),
                              const SizedBox(width: 8),
                              _ActionButton(
                                icon: _SvgAssets.share,
                                label: 'Share',
                                onTap: () => onShare(item.displayText),
                              ),
                            ],
                          ),
                          _ActionButton(
                            icon: item.liked ? _SvgAssets.heartFilled : _SvgAssets.heart,
                            label: item.liked ? 'Liked!' : 'Like',
                            active: item.liked,
                            activeBackground: const Color.fromRGBO(
                              232,
                              72,
                              85,
                              0.12,
                            ),
                            activeForeground: const Color(0xFFE84855),
                            onTap: onLike,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const palettes = <List<Color>>[
      [Color(0xFFFFB6C1), Color(0xFFAEC6CF), Color(0xFFFDF9E4)],
      [Color(0xFFE4F0FD), Color(0xFFE4FDE8), Color(0xFFF0E4FD)],
      [Color(0xFFFFDAB9), Color(0xFFE6E6FA), Color(0xFFE0FFFF)],
      [Color(0xFFF08080), Color(0xFFFFD700), Color(0xFF98FB98)],
      [Color(0xFFFDE4E4), Color(0xFFE4F0FD), Color(0xFFFDF9E4)],
    ];
    final palette = palettes[index % palettes.length];

    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.6, -0.4),
                    radius: 0.9,
                    colors: <Color>[palette[0].withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.6, 0.5),
                    radius: 0.9,
                    colors: <Color>[palette[1].withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 0.8),
                    radius: 0.9,
                    colors: <Color>[palette[2].withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangDot extends StatelessWidget {
  const _LangDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFFC9A84C),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeBackground,
    this.activeForeground,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeBackground;
  final Color? activeForeground;

  @override
  Widget build(BuildContext context) {
    final foreground = activeForeground ?? const Color(0xFF444444);
    final background = active
        ? activeBackground ?? const Color.fromRGBO(0, 0, 0, 0.05)
        : const Color.fromRGBO(0, 0, 0, 0.05);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.string(
                icon,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SvgAssets {
  static const String copy =
      '''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>''';
  static const String share =
      '''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></svg>''';
  static const String heart =
      '''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>''';
  static const String heartFilled =
      '''<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>''';
}

