import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/fact_card_state.dart';

class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key, required this.items, required this.onRemove});

  final List<FactCardState> items;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeTop = MediaQuery.of(context).padding.top;

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No liked facts yet',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: const Color(0xFF888888),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20, safeTop + 80, 20, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.displayText,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => onRemove(item.id),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
