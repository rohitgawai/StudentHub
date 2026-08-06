import 'package:flutter/material.dart';
import '../models/post_model.dart';
import 'device_file_picker_dialog.dart';

class PdfUploadField extends StatefulWidget {
  final ValueChanged<List<PostAttachment>> onAttachmentChanged;

  const PdfUploadField({
    super.key,
    required this.onAttachmentChanged,
  });

  @override
  State<PdfUploadField> createState() => _PdfUploadFieldState();
}

class _PdfUploadFieldState extends State<PdfUploadField> {
  String? selectedDocTitle = 'Official_Department_Syllabus_2026.pdf';
  String fileSize = '1.4 MB';

  @override
  void initState() {
    super.initState();
    _updateAttachment();
  }

  Future<void> _pickPdfFromDevice() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const DeviceFilePickerDialog(
        isPdfOnly: true,
        title: 'Upload PDF Document from Device Storage',
      ),
    );

    if (result != null && result['name'] != null) {
      setState(() {
        selectedDocTitle = result['name'];
        fileSize = result['size'] ?? '1.5 MB';
      });
      _updateAttachment();
    }
  }

  void _clearPdf() {
    setState(() {
      selectedDocTitle = null;
    });
    widget.onAttachmentChanged([]);
  }

  void _updateAttachment() {
    if (selectedDocTitle == null) {
      widget.onAttachmentChanged([]);
      return;
    }

    final attachment = PostAttachment(
      title: selectedDocTitle!,
      fileType: 'pdf',
      url: 'official_document.pdf',
      fileSize: fileSize,
    );
    widget.onAttachmentChanged([attachment]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Device PDF Document Attachment',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
              if (selectedDocTitle != null)
                GestureDetector(
                  onTap: _clearPdf,
                  child: const Text(
                    'Remove PDF',
                    style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (selectedDocTitle != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedDocTitle!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Size: $fileSize • Ready for student feeds',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _pickPdfFromDevice,
                    child: const Text('Change File', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pickPdfFromDevice,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('📄 Browse & Upload PDF Document from Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
