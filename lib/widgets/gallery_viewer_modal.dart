import 'package:flutter/material.dart';
import 'app_image.dart';

/// Opens the full-screen gallery viewer with a swipeable slideshow and pinch
/// zoom. Close by tapping anywhere on the screen, pressing the back button,
/// or swiping down when not zoomed in.
void showGalleryViewer(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return;
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (ctx, animation, secondary) => GalleryViewerModal(
        images: images,
        initialIndex: initialIndex.clamp(0, images.length - 1),
      ),
      transitionsBuilder: (ctx, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    ),
  );
}

class GalleryViewerModal extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const GalleryViewerModal({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<GalleryViewerModal> createState() => _GalleryViewerModalState();
}

class _GalleryViewerModalState extends State<GalleryViewerModal>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _current = widget.initialIndex;

  // Swipe-down-to-dismiss state (raw pointer tracking, so it works even
  // though InteractiveViewer consumes the drag gesture).
  late final AnimationController _releaseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  double _downY = 0;
  double _dragDy = 0;
  bool _zoomed = false;
  bool _dismissing = false;
  double _releaseStart = 0;
  double _releaseTarget = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _releaseCtrl.dispose();
    super.dispose();
  }

  void _releaseTo(double target, {VoidCallback? onDone}) {
    _releaseStart = _dragDy;
    _releaseTarget = target;
    _releaseCtrl.forward(from: 0).whenComplete(onDone ?? () {});
  }

  void _handleRelease() {
    final t = Curves.easeOut.transform(_releaseCtrl.value);
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
    if (_dismissing || _zoomed) return;
    final dy = e.position.dy - _downY;
    if (dy > 0) {
      setState(() => _dragDy = dy);
    }
  }

  void _onPointerEnd(PointerEvent e) {
    if (_dismissing || _zoomed) return;
    if (_dragDy > 120) {
      // Past the threshold: slide the viewer off-screen and close.
      _dismissing = true;
      _releaseCtrl.addListener(_handleRelease);
      _releaseTo(
        MediaQuery.sizeOf(context).height * 0.8,
        onDone: () {
          _releaseCtrl.removeListener(_handleRelease);
          if (mounted) Navigator.of(context).pop();
        },
      );
    } else if (_dragDy > 0) {
      // Under the threshold: spring back to rest.
      _releaseCtrl.addListener(_handleRelease);
      _releaseTo(0, onDone: () => _releaseCtrl.removeListener(_handleRelease));
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final opacity = (1 - (_dragDy / (MediaQuery.sizeOf(context).height * 0.6)))
        .clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: Stack(
          children: [
            // Tap anywhere on the black backdrop to close.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Transform.translate(
                offset: Offset(0, _dragDy),
                child: Opacity(
                  opacity: opacity,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (i) {
                      setState(() {
                        _current = i;
                        _zoomed = false;
                        _dragDy = 0;
                      });
                    },
                    itemBuilder: (context, index) => _ZoomableImage(
                      source: images[index],
                      onZoomChanged: (zoomed) {
                        if (_zoomed != zoomed) {
                          setState(() => _zoomed = zoomed);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Close (X) button.
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 12,
              child: Material(
                color: Colors.black38,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // Slideshow position indicator.
            if (images.length > 1)
              Positioned(
                bottom: MediaQuery.paddingOf(context).bottom + 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) {
                    final active = i == _current;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

            if (images.length > 1)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_current + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

/// A single viewer slide: pinch to zoom (1x-5x), single-finger drag pans
/// while zoomed in, and reports its zoom state so the parent can decide
/// whether swipe-down should dismiss the viewer.
class _ZoomableImage extends StatefulWidget {
  final String source;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableImage({
    required this.source,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reportZoom);
  }

  void _reportZoom() {
    widget.onZoomChanged(_controller.value.getMaxScaleOnAxis() > 1.05);
  }

  @override
  void dispose() {
    _controller.removeListener(_reportZoom);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1,
      maxScale: 5,
      panEnabled: true,
      scaleEnabled: true,
      child: Center(
        child: AppImage(
          source: widget.source,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}