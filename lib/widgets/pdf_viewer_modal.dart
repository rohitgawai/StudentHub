import 'package:flutter/material.dart';
import '../models/post_model.dart';

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
  int currentPage = 1;
  final int totalPages = 4;
  double zoomLevel = 1.0;

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {
                if (zoomLevel > 0.8) setState(() => zoomLevel -= 0.2);
              },
            ),
            Center(
              child: Text(
                '${(zoomLevel * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: () {
                if (zoomLevel < 2.0) setState(() => zoomLevel += 0.2);
              },
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download Attachment',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloading ${widget.attachment.title}...'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Column(
          children: [
            // Page Navigator Bar
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 16),
                        onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                      ),
                      Text(
                        'Page $currentPage of $totalPages',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        onPressed: currentPage < totalPages ? () => setState(() => currentPage++) : null,
                      ),
                    ],
                  ),
                  const Chip(
                    avatar: Icon(Icons.verified, size: 14, color: Colors.blue),
                    label: Text('Digitally Signed by MIT Academics', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            // Mock PDF Content View
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Transform.scale(
                      scale: zoomLevel,
                      child: Container(
                        width: 600,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'ST. ANDREW INSTITUTE OF TECH & SCI',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E88E5),
                                      ),
                                    ),
                                    Text('Office of Academic Affairs & Examinations',
                                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.school, color: Color(0xFF1E88E5)),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            Text(
                              'DOCUMENT REF: ${widget.attachment.title}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'OFFICIAL ACADEMIC NOTIFICATION - PAGE $currentPage',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'This document serves as an official notice issued to all enrolled students and faculty members. Please ensure strict compliance with the schedules, guidelines, and timelines mentioned herein.',
                              style: TextStyle(height: 1.5, fontSize: 13, color: Colors.black87),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.info_outline, color: Colors.amber),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Important Note: Any requests for adjustments must be submitted via the StudentHub portal within 48 hours of publication.',
                                      style: TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('Issued Date: Aug 06, 2026', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('Registrar Signature: [VERIFIED]', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
