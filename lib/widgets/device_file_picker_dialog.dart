import 'package:flutter/material.dart';

class DeviceFilePickerDialog extends StatefulWidget {
  final bool isPdfOnly;
  final String title;

  const DeviceFilePickerDialog({
    super.key,
    this.isPdfOnly = false,
    this.title = 'Select File from Device Storage',
  });

  @override
  State<DeviceFilePickerDialog> createState() => _DeviceFilePickerDialogState();
}

class _DeviceFilePickerDialogState extends State<DeviceFilePickerDialog> {
  static const List<Map<String, String>> devicePhotos = [
    {
      'name': 'IMG_20260806_DCIM.jpg',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=600',
      'size': '2.4 MB',
      'folder': 'Internal Storage / DCIM / Camera',
    },
    {
      'name': 'Campus_Event_Photo.jpg',
      'url': 'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?auto=format&fit=crop&q=80&w=600',
      'size': '3.1 MB',
      'folder': 'Internal Storage / Pictures / Gallery',
    },
    {
      'name': 'AI_Tech_Workshop.png',
      'url': 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&q=80&w=600',
      'size': '1.8 MB',
      'folder': 'Internal Storage / Downloads',
    },
    {
      'name': 'Sports_Match_Capture.jpg',
      'url': 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=600',
      'size': '4.2 MB',
      'folder': 'Internal Storage / DCIM / Camera',
    },
    {
      'name': 'Profile_Avatar_Student.png',
      'url': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&q=80&w=600',
      'size': '1.5 MB',
      'folder': 'Internal Storage / Pictures',
    },
  ];

  static const List<Map<String, String>> devicePdfs = [
    {
      'name': 'Official_Department_Syllabus_2026.pdf',
      'size': '1.4 MB',
      'folder': 'Internal Storage / Downloads',
      'date': 'Today, 14:20',
    },
    {
      'name': 'Mid_Sem_Exam_Schedule_Autumn.pdf',
      'size': '2.8 MB',
      'folder': 'Internal Storage / Documents',
      'date': 'Yesterday, 10:15',
    },
    {
      'name': 'Placement_Drive_Eligibility_Rules.pdf',
      'size': '890 KB',
      'folder': 'Internal Storage / Downloads',
      'date': '04 Aug 2026',
    },
    {
      'name': 'Campus_Event_Rulebook_Guidance.pdf',
      'size': '1.8 MB',
      'folder': 'Internal Storage / Documents',
      'date': '01 Aug 2026',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(widget.isPdfOnly ? Icons.picture_as_pdf : Icons.folder_open_rounded, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            Text(
              widget.isPdfOnly
                  ? '📁 Select PDF document from Device Storage:'
                  : '📷 Select Image file from Device Gallery / Storage:',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              child: widget.isPdfOnly ? _buildPdfList(context) : _buildImageList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: devicePhotos.length,
      itemBuilder: (ctx, idx) {
        final photo = devicePhotos[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                photo['url']!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(photo['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('${photo['folder']} • ${photo['size']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: () {
                Navigator.of(context).pop({
                  'name': photo['name'],
                  'url': photo['url'],
                  'size': photo['size'],
                });
              },
              child: const Text('Select', style: TextStyle(fontSize: 12)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPdfList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: devicePdfs.length,
      itemBuilder: (ctx, idx) {
        final pdf = devicePdfs[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
            ),
            title: Text(pdf['name']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text('${pdf['folder']} • ${pdf['size']} • ${pdf['date']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: () {
                Navigator.of(context).pop({
                  'name': pdf['name'],
                  'size': pdf['size'],
                });
              },
              child: const Text('Select PDF', style: TextStyle(fontSize: 11)),
            ),
          ),
        );
      },
    );
  }
}
