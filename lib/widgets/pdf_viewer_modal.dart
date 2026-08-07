import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post_model.dart';
import '../services/local_store_service.dart';

class PdfViewerModal extends StatefulWidget {
  final PostAttachment attachment;

  const PdfViewerModal({super.key, required this.attachment});

  @override
  State<PdfViewerModal> createState() => _PdfViewerModalState();
}

class _PdfViewerModalState extends State<PdfViewerModal> {
  final PdfViewerController _controller = PdfViewerController();

  Uint8List? _pdfBytes;
  String? _error;
  bool _viewerReady = false;
  int _pageCount = 0;
  int _currentPage = 1;
  double _zoomDisplay = 1.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerValue);
    _loadPdf();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerValue);
    super.dispose();
  }

  Future<void> _loadPdf() async {
    final url = widget.attachment.url;
    try {
      final bytes = await _resolveBytes(url);
      if (!mounted || bytes == null) return;
      setState(() => _pdfBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open this PDF file: $e');
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

  void _onControllerValue() {
    if (!mounted || !_viewerReady) return;
    final zoom = _controller.currentZoom;
    final page = _controller.pageNumber;
    if (zoom == _zoomDisplay && (page == null || page == _currentPage)) return;
    setState(() {
      _zoomDisplay = zoom;
      if (page != null) _currentPage = page;
    });
  }

  /// Auto-adjusts the view so the page width fits the screen on any device.
  void _fitToWidth() {
    final controller = _controller;
    if (!controller.isReady) return;
    final page = controller.pageNumber ?? 1;
    final matrix = controller.calcMatrixFitWidthForPage(pageNumber: page);
    if (matrix != null) {
      controller.goTo(matrix, duration: Duration.zero);
    }
  }

  void _zoomBy(int delta) {
    final controller = _controller;
    if (!controller.isReady) return;
    final zoom = delta > 0
        ? controller.getNextZoom()
        : controller.getPreviousZoom();
    controller.setZoom(controller.centerPosition, zoom);
  }

  void _goToPage(int page) {
    _controller.goToPage(pageNumber: page);
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
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDoc = _pdfBytes != null && _error == null;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.attachment.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
              onPressed: _viewerReady ? () => _zoomBy(-1) : null,
            ),
            Center(
              child: Text(
                _viewerReady ? '${(_zoomDisplay * 100).round()}%' : '100%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: 'Zoom in',
              onPressed: _viewerReady ? () => _zoomBy(1) : null,
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
            if (hasDoc && _pageCount > 0)
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 16),
                          tooltip: 'Previous page',
                          onPressed: _currentPage > 1
                              ? () => _goToPage(_currentPage - 1)
                              : null,
                        ),
                        Text(
                          'Page $_currentPage of $_pageCount',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          tooltip: 'Next page',
                          onPressed: _currentPage < _pageCount
                              ? () => _goToPage(_currentPage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
    if (_pdfBytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PdfViewer.data(
      _pdfBytes!,
      sourceName: widget.attachment.title,
      controller: _controller,
      params: PdfViewerParams(
        backgroundColor: const Color(0xFFE9E9EC),
        margin: 8,
        pageDropShadow: const BoxShadow(
          color: Colors.black26,
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
        sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
          minScale: 0.25,
          maxScale: 5.0,
        ),
        panEnabled: true,
        scaleEnabled: true,
        scrollByMouseWheel: 1.0,
        enableKeyboardNavigation: true,
        onViewerReady: (document, controller) {
          if (!mounted) return;
          setState(() {
            _viewerReady = true;
            _pageCount = document.pages.length;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitToWidth();
          });
        },
        onPageChanged: (page) {
          if (mounted && page != null && page != _currentPage) {
            setState(() => _currentPage = page);
          }
        },
      ),
    );
  }
}
