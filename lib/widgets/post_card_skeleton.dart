import 'package:flutter/material.dart';

/// Pulsing skeleton placeholder shown while the feed is loading, so the UI
/// never pops from nothing straight into content.
class PostCardSkeleton extends StatefulWidget {
  const PostCardSkeleton({super.key});

  @override
  State<PostCardSkeleton> createState() => _PostCardSkeletonState();
}

class _PostCardSkeletonState extends State<PostCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    final highlight = Theme.of(context).cardColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = 0.55 + (_controller.value * 0.25);
        Widget box(double w, double h, [double radius = 8]) {
          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: Color.lerp(base, highlight, value),
              borderRadius: BorderRadius.circular(radius),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  box(36, 36, 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        box(double.infinity, 12),
                        const SizedBox(height: 6),
                        box(120, 10),
                      ],
                    ),
                  ),
                  box(80, 22, 11),
                ],
              ),
              const SizedBox(height: 14),
              box(double.infinity, 18),
              const SizedBox(height: 8),
              box(double.infinity, 12),
              const SizedBox(height: 6),
              box(200, 12),
              const SizedBox(height: 14),
              box(double.infinity, 140, 12),
            ],
          ),
        );
      },
    );
  }
}

/// A full-screen skeleton of the feed.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: 6,
      itemBuilder: (context, index) => const PostCardSkeleton(),
    );
  }
}