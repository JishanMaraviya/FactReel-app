import 'package:flutter/material.dart';

class FactSkeletonCard extends StatefulWidget {
  const FactSkeletonCard({super.key});

  @override
  State<FactSkeletonCard> createState() => _FactSkeletonCardState();
}

class _FactSkeletonCardState extends State<FactSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 480;
    final radius = compact ? 22.0 : 28.0;
    final padding = compact
        ? const EdgeInsets.fromLTRB(22, 28, 22, 22)
        : const EdgeInsets.fromLTRB(32, 36, 32, 28);

    final safeTop = MediaQuery.of(context).padding.top;

    return Container(
      height: double.infinity,
      padding: EdgeInsets.fromLTRB(20, safeTop + 130, 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SkeletonPill(width: 110, height: 24, radius: 50),
                    _SkeletonPill(width: 60, height: 18, radius: 6),
                  ],
                ),
                SizedBox(height: 18),
                Column(
                  children: [
                    _SkeletonLine(),
                    SizedBox(height: 10),
                    _SkeletonLine(),
                    SizedBox(height: 10),
                    _SkeletonLine(widthFactor: 0.8),
                    SizedBox(height: 10),
                    _SkeletonLine(widthFactor: 0.6),
                  ],
                ),
                SizedBox(height: 18),
                _SkeletonPill(width: double.infinity, height: 38, radius: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEBEBEB),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({this.widthFactor = 1});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: _Shimmer(
        child: Container(
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFFEBEBEB),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: -1, end: 2),
      duration: const Duration(milliseconds: 1400),
      builder: (context, value, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFEBEBEB),
                Color(0xFFF5F5F5),
                Color(0xFFEBEBEB),
              ],
              stops: const [0.25, 0.5, 0.75],
              transform: _SlidingGradientTransform(value),
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}
