import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mock_data_service.dart';
import 'device_file_picker_dialog.dart';

class ProfileAvatarZoomDialog extends StatefulWidget {
  final String avatarUrl;

  const ProfileAvatarZoomDialog({
    super.key,
    required this.avatarUrl,
  });

  @override
  State<ProfileAvatarZoomDialog> createState() => _ProfileAvatarZoomDialogState();
}

class _ProfileAvatarZoomDialogState extends State<ProfileAvatarZoomDialog> {
  bool isEditing = false;
  late String currentAvatar;

  @override
  void initState() {
    super.initState();
    currentAvatar = widget.avatarUrl;
  }

  Future<void> _pickAvatarFromDevice() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const DeviceFilePickerDialog(
        isPdfOnly: false,
        title: 'Upload Profile Picture from Device',
      ),
    );

    if (result != null && result['url'] != null) {
      _updateAvatar(result['url']!);
    }
  }

  void _updateAvatar(String newUrl) {
    final dataService = Provider.of<MockDataService>(context, listen: false);
    final u = dataService.currentUser;
    dataService.updateUserProfile(
      name: u.name,
      department: u.department,
      year: u.year,
      avatarUrl: newUrl,
    );
    setState(() {
      currentAvatar = newUrl;
      isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📸 Profile picture updated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.92),
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile Picture',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(isEditing ? Icons.close : Icons.edit, color: Colors.white),
                      tooltip: 'Edit / Update Photo',
                      onPressed: () => setState(() => isEditing = !isEditing),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Zoomable Instagram Style Image
          if (!isEditing) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 380),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: currentAvatar.isNotEmpty
                      ? Image.network(
                          currentAvatar,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => const Icon(
                            Icons.person,
                            size: 160,
                            color: Colors.white54,
                          ),
                        )
                      : const Icon(Icons.person, size: 160, color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '🔍 Pinch or double-tap to zoom like Instagram',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ] else ...[
            // Edit Avatar via Direct Device Picker (No URL link option)
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload New Profile Photo:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select a photo directly from your device gallery or camera storage.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text(
                        '📁 Upload Photo from Device Storage',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _pickAvatarFromDevice,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
