import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import 'app_image.dart';

/// Opens a dedicated social-media style image zoom-in modal.
/// Presents the image in a framed card size (matching post card dimensions)
/// with a blurred dark backdrop, interactive pinch & double-tap zoom,
/// bi-directional slide up / slide down dismissal, and a top close button.
void showPostImageZoomModal(
  BuildContext context, {
  required String imageUrl,
  String? title,
  PostCategory? category,
  String? authorName,
  String? department,
  String? heroTag,
}) {
  if (imageUrl.trim().isEmpty) return;

  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, animation, secondaryAnimation) => PostImageZoomModal(
        imageUrl: imageUrl,
        title: title,
        category: category,
        authorName: authorName,
        department: department,
        heroTag: heroTag,
      ),
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
    ),
  );
}

class PostImageZoomModal extends StatefulWidget {
  final String imageUrl;
  final String? title;
  final PostCategory? category;
  final String? authorName;
  final String? department;
  final String? heroTag;

  const PostImageZoomModal({
    super.key,
    required this.imageUrl,
    this.title,
    this.category,
    this.authorName,
    this.department,
    this.heroTag,
  });

  @override
  State<PostImageZoomModal> createState() => _PostImageZoomModalState();
}

class _PostImageZoomModalState extends State<PostImageZoomModal>
    with TickerProviderStateMixin {
  final TransformationController _transformCtrl = TransformationController();
  late final AnimationController _releaseCtrl;
  late final AnimationController _doubleTapZoomCtrl;
  Animation<Matrix4>? _doubleTapAnimation;

  double _downY = 0;
  double _dragDy = 0;
  bool _isZoomed = false;
  bool _dismissing = false;
  double _releaseStart = 0;
  double _releaseTarget = 0;

  @override
  void initState() {
    super.initState();
    _releaseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _doubleTapZoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _transformCtrl.addListener(_onTransformationChanged);
  }

  void _onTransformationChanged() {
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  @override
  void dispose() {
    _transformCtrl.removeListener(_onTransformationChanged);
    _transformCtrl.dispose();
    _releaseCtrl.dispose();
    _doubleTapZoomCtrl.dispose();
    super.dispose();
  }

  void _releaseTo(double target, {VoidCallback? onDone}) {
    _releaseStart = _dragDy;
    _releaseTarget = target;
    _releaseCtrl.forward(from: 0).whenComplete(onDone ?? () {});
  }

  void _handleRelease() {
    final t = Curves.easeOutCubic.transform(_releaseCtrl.value);
    setState(() {
      _dragDy = _releaseStart + (_releaseTarget - _releaseStart) * t;
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_dismissing) return;
    _downY = e.position.dy;
    _dragDy = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_dismissing || _isZoomed) return;
    final dy = e.position.dy - _downY;
    setState(() => _dragDy = dy);
  }

  void _onPointerEnd(PointerEvent e) {
    if (_dismissing || _isZoomed) return;
    final screenH = MediaQuery.sizeOf(context).height;
    const threshold = 90.0;

    if (_dragDy > threshold) {
      // Swiped DOWN past threshold: slide downwards and dismiss
      _dismissing = true;
      _releaseCtrl.addListener(_handleRelease);
      _releaseTo(
        screenH * 0.75,
        onDone: () {
          _releaseCtrl.removeListener(_handleRelease);
          if (mounted) Navigator.of(context).pop();
        },
      );
    } else if (_dragDy < -threshold) {
      // Swiped UP past threshold: slide upwards and dismiss
      _dismissing = true;
      _releaseCtrl.addListener(_handleRelease);
      _releaseTo(
        -screenH * 0.75,
        onDone: () {
          _releaseCtrl.removeListener(_handleRelease);
          if (mounted) Navigator.of(context).pop();
        },
      );
    } else if (_dragDy != 0) {
      // Under threshold: spring smoothly back to rest position
      _releaseCtrl.addListener(_handleRelease);
      _releaseTo(0, onDone: () => _releaseCtrl.removeListener(_handleRelease));
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale = _transformCtrl.value.getMaxScaleOnAxis();
    final begin = _transformCtrl.value;
    Matrix4 end;

    if (currentScale > 1.2) {
      // Reset back to normal 1.0x
      end = Matrix4.identity();
    } else {
      // Zoom into tapped point at 2.5x
      final position = details.localPosition;
      final x = -position.dx * (2.5 - 1.0);
      final y = -position.dy * (2.5 - 1.0);
      end = Matrix4.identity()
        ..storage[0] = 2.5
        ..storage[5] = 2.5
        ..storage[12] = x
        ..storage[13] = y;
    }

    _doubleTapAnimation = Matrix4Tween(begin: begin, end: end).animate(
      CurvedAnimation(parent: _doubleTapZoomCtrl, curve: Curves.easeOutCubic),
    )..addListener(() {
        _transformCtrl.value = _doubleTapAnimation!.value;
      });

    _doubleTapZoomCtrl.forward(from: 0);
  }

  Widget _buildCategoryBadge() {
    if (widget.category == null) return const SizedBox.shrink();

    String label;
    IconData icon;
    Color color;

    switch (widget.category!) {
      case PostCategory.event:
        label = 'Event Banner';
        icon = Icons.event_rounded;
        color = const Color(0xFF6366F1);
        break;
      case PostCategory.workshop:
        label = 'Workshop Cover';
        icon = Icons.psychology_alt_rounded;
        color = const Color(0xFF818CF8);
        break;
      case PostCategory.achievement:
        label = 'Achievement';
        icon = Icons.emoji_events_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case PostCategory.placement:
        label = 'Placement';
        icon = Icons.work_rounded;
        color = const Color(0xFF10B981);
        break;
      case PostCategory.gallery:
        label = 'Gallery Photo';
        icon = Icons.photo_library_rounded;
        color = const Color(0xFF0284C7);
        break;
      case PostCategory.academic:
        label = 'Academic';
        icon = Icons.school_rounded;
        color = const Color(0xFF3B82F6);
        break;
      case PostCategory.urgent:
        label = 'Urgent Notice';
        icon = Icons.warning_rounded;
        color = const Color(0xFFEF4444);
        break;
      case PostCategory.announcement:
        label = 'Post Image';
        icon = Icons.campaign_rounded;
        color = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;

    // Dedicated framed sizing: looks like the post image on mobile/tablet/desktop
    final maxCardWidth = (screenSize.width - 32).clamp(280.0, 540.0);
    final maxCardHeight = screenSize.height * 0.68;

    final dragFraction = (_dragDy.abs() / (screenSize.height * 0.5)).clamp(0.0, 1.0);
    final backdropOpacity = (1.0 - dragFraction).clamp(0.0, 1.0);
    final cardScale = (1.0 - (dragFraction * 0.15)).clamp(0.85, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred Dark Backdrop (Tap to Close)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: backdropOpacity,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ),
          ),

          // Main Interactive Zoom & Drag Area
          Positioned.fill(
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerEnd,
              onPointerCancel: _onPointerEnd,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, _dragDy),
                  child: Transform.scale(
                    scale: cardScale,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxCardWidth,
                        maxHeight: maxCardHeight,
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: GestureDetector(
                          onDoubleTapDown: _handleDoubleTap,
                          onDoubleTap: () {}, // Handled in onDoubleTapDown
                          child: InteractiveViewer(
                            transformationController: _transformCtrl,
                            minScale: 1.0,
                            maxScale: 4.5,
                            panEnabled: true,
                            scaleEnabled: false,
                            clipBehavior: Clip.hardEdge,
                            child: widget.heroTag != null
                                ? Hero(
                                    tag: widget.heroTag!,
                                    child: AppImage(
                                      source: widget.imageUrl,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  )
                                : AppImage(
                                    source: widget.imageUrl,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top Header Bar (Social Media light-box header with Close X)
          Positioned(
            top: padding.top + 8,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: backdropOpacity,
              child: Row(
                children: [
                  // Category badge or Post Title
                  if (widget.category != null) ...[
                    _buildCategoryBadge(),
                    const SizedBox(width: 10),
                  ],
                  if (widget.title != null && widget.title!.isNotEmpty)
                    Expanded(
                      child: Text(
                        widget.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Spacer(),

                  // Modern Frosted Close Button
                  Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Quick Hint Pill (Subtle micro-interaction guide)
          Positioned(
            bottom: padding.bottom + 18,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: (_isZoomed || backdropOpacity < 0.8) ? 0.0 : 1.0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.touch_app_outlined, size: 14, color: Colors.white70),
                      SizedBox(width: 6),
                      Text(
                        'Double tap to zoom • Swipe up / down to close',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
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
