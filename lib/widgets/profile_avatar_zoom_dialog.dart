import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_file_service.dart';
import '../services/mock_data_service.dart';
import 'app_image.dart';

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
  late String currentAvatar;

  @override
  void initState() {
    super.initState();
    currentAvatar = widget.avatarUrl;
  }

  Future<void> _pickAvatarFromDevice() async {
    try {
      final picked = await pickImageFromDevice();
      if (picked != null && picked.source != null) {
        if (!mounted) return;
        _updateAvatar(picked.source!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Could not open device gallery. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
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
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📸 Profile picture updated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeAvatar() {
    final dataService = Provider.of<MockDataService>(context, listen: false);
    final u = dataService.currentUser;
    dataService.updateUserProfile(
      name: u.name,
      department: u.department,
      year: u.year,
      avatarUrl: '',
    );
    setState(() {
      currentAvatar = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile picture removed.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final squareBoxSize = screenSize.width.clamp(280.0, 380.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // WhatsApp / Instagram Top Bar (Clean with Back and Title only)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: const Color(0xFF0F172A),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Profile photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Specific 1:1 Aspect Ratio Selective Frame
            SizedBox(
              width: squareBoxSize,
              height: squareBoxSize,
              child: Container(
                color: const Color(0xFF020617),
                child: ClipRect(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    clipBehavior: Clip.hardEdge,
                    child: currentAvatar.isNotEmpty
                        ? AppImage(
                            source: currentAvatar,
                            fit: BoxFit.cover,
                            width: squareBoxSize,
                            height: squareBoxSize,
                            errorChild: const Center(
                              child: Icon(
                                Icons.person,
                                size: 120,
                                color: Colors.white30,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.person,
                              size: 120,
                              color: Colors.white30,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // Bottom Quick Action Bar (Edit Photo & Remove Photo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _pickAvatarFromDevice,
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 20),
                    label: const Text(
                      'Edit Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  if (currentAvatar.isNotEmpty)
                    TextButton.icon(
                      onPressed: _removeAvatar,
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      label: const Text(
                        'Remove Photo',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
