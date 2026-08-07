import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post_model.dart';
import '../services/local_store_service.dart';

class _RenderedPdfPage {
  _RenderedPdfPage(this.image, this.aspectRatio);

  final ui.Image image;

  /// Page width / height.
  final double aspectRatio;
}

class PdfViewerModal extends StatefulWidget {
  final PostAttachment attachment;

  const PdfViewerModal({
    super.key,
    required this.attachment,
  });

  @override
  State<PdfViewerModal> createState() => _PdfViewerModalState();
}

class _PdfViewerModalState extends State<PdfViewerModal> {
  static const List<double> _zoomSteps = [0.75, 1.0, 1.5, 2.0, 3.0];

  final ScrollController _scrollController = ScrollController();
  final List<double> _pageExtents = [];

  PdfDocument? _document;
  Uint8List? _pdfBytes;
  String? _error;

  final List<_RenderedPdfPage> _pages = [];
  int _zoomIndex = 1;
  int _renderTask = 0;
  bool _rendering = false;
  double _viewportWidth = 0;
  double _viewportHeight = 0;
  int _currentPage = 1;

  double get _zoom => _zoomSteps[_zoomIndex];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPdf();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final page in _pages) {
      page.image.dispose();
    }
    _document?.dispose();
    super.dispose();
  }

  void _onScroll() {
    final page = _computeCurrentPage();
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  int _computeCurrentPage() {
    if (_pageExtents.isEmpty || _viewportHeight <= 0) return 1;
    final target = _scrollController.offset + _viewportHeight / 2;
    var cumulative = 0.0;
    for (var i = 0; i < _pageExtents.length; i++) {
      cumulative += _pageExtents[i];
      if (target <= cumulative) return i + 1;
    }
    return _pageExtents.length;
  }

  Future<void> _loadPdf() async {
    final url = widget.attachment.url;
    try {
      final bytes = await _resolveBytes(url);
      if (!mounted || bytes == null) return;
      final doc = await PdfDocument.openData(bytes);
      if (!mounted) {
        doc.dispose();
        return;
      }
      setState(() {
        _document = doc;
        _pdfBytes = bytes;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open this PDF file: $e';
      });
    }
  }

  /// Resolves PDF bytes from a base64 data URI, a locally stored `local://`
  /// blob, an HTTP(S) URL, or a bundled asset path.
  Future<Uint8List?> _resolveBytes(String url) async {
    if (url.startsWith('data:')) {
      final commaIndex = url.indexOf(',');
      if (commaIndex == -1) {
        throw Exception('Invalid base64 data URI');
      }
      return base64Decode(url.substring(commaIndex + 1));
    }
    if (url.startsWith(LocalStoreService.localPrefix)) {
      final bytes = await LocalStoreService.instance.readLocalBlob(url);
      if (bytes == null) {
        throw Exception('Local attachment is no longer available');
      }
      return bytes;
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }
      return response.bodyBytes;
    }
    final data = await rootBundle.load(url);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<void> _renderAllPages() async {
    final doc = _document;
    if (doc == null || _viewportWidth <= 0) return;
    final task = ++_renderTask;
    for (final page in _pages) {
      page.image.dispose();
    }
    _pages.clear();
    _pageExtents.clear();

    setState(() => _rendering = true);

    final displayWidth = _viewportWidth * _zoom;
    final renderWidth = (displayWidth * MediaQuery.devicePixelRatioOf(context)).round();

    try {
      for (var i = 0; i < doc.pages.length; i++) {
        if (task != _renderTask || !mounted) return;
        final page = doc.pages[i];
        final pdfImage = await page.render(width: renderWidth);
        if (pdfImage == null) continue;
        final uiImage = await _pdfImageToUiImage(pdfImage);
        pdfImage.dispose();
        if (task != _renderTask || !mounted) {
          uiImage.dispose();
          return;
        }
        final rendered = _RenderedPdfPage(uiImage, page.width / page.height);
        final extent = displayWidth / rendered.aspectRatio + 24;
        setState(() {
          _pages.add(rendered);
          _pageExtents.add(extent);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not render this PDF file: $e';
      });
    } finally {
      if (task == _renderTask && mounted) {
        setState(() => _rendering = false);
      }
    }
  }

  Future<ui.Image> _pdfImageToUiImage(PdfImage pdfImage) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pdfImage.pixels,
      pdfImage.width,
      pdfImage.height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    return completer.future;
  }

  void _changeZoom(int delta) {
    final next = (_zoomIndex + delta).clamp(0, _zoomSteps.length - 1);
    if (next == _zoomIndex) return;
    setState(() => _zoomIndex = next);
    _renderAllPages();
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _pageExtents.length) return;
    var offset = 0.0;
    for (var i = 0; i < page - 1; i++) {
      offset += _pageExtents[i];
    }
    await _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _shareDocument() async {
    final bytes = _pdfBytes;
    if (bytes == null) {
      _showSnack('Document content is not available for download.');
      return;
    }
    try {
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: widget.attachment.title,
          ),
        ],
        subject: widget.attachment.title,
        fileNameOverrides: [widget.attachment.title],
      );
    } catch (_) {
      _showSnack('Could not share this document.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _document?.pages.length ?? 0;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.attachment.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'PDF Document • ${widget.attachment.fileSize}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Zoom out',
              onPressed: _zoomIndex > 0 && pageCount > 0 ? () => _changeZoom(-1) : null,
            ),
            Center(
              child: Text(
                '${(_zoom * 100).round()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: 'Zoom in',
              onPressed: _zoomIndex < _zoomSteps.length - 1 && pageCount > 0
                  ? () => _changeZoom(1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download / Share Attachment',
              onPressed: _shareDocument,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Column(
          children: [
            if (pageCount > 0) ...[
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 16),
                          tooltip: 'Previous page',
                          onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                        ),
                        Text(
                          'Page $_currentPage of $pageCount',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          tooltip: 'Next page',
                          onPressed: _currentPage < pageCount
                              ? () => _goToPage(_currentPage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_rendering && _pages.isNotEmpty)
                const LinearProgressIndicator(minHeight: 2),
            ],
            Expanded(child: _buildContentView()),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    if (_document == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        _viewportHeight = constraints.maxHeight;

        if (_pages.isEmpty && !_rendering && _document != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _pages.isEmpty &&
                !_rendering &&
                _document != null &&
                _error == null) {
              _renderAllPages();
            }
          });
        }

        final zoomed = _zoom * constraints.maxWidth > constraints.maxWidth + 0.5;

        Widget list = ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _pages.length,
          itemBuilder: (context, index) {
            final page = _pages[index];
            final width = constraints.maxWidth * _zoom;
            final height = width / page.aspectRatio;
            return Container(
              width: width,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: RawImage(image: page.image, fit: BoxFit.fill),
            );
          },
        );

        if (zoomed) {
          list = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth * _zoom,
              child: list,
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: list),
            if (_rendering && _pages.isEmpty)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }
}
