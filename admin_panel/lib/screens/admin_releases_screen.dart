import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_supabase_service.dart';
import '../theme/admin_theme.dart';

class AdminReleasesScreen extends StatefulWidget {
  const AdminReleasesScreen({super.key});

  @override
  State<AdminReleasesScreen> createState() => _AdminReleasesScreenState();
}

class _AdminReleasesScreenState extends State<AdminReleasesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _versionNameCtrl = TextEditingController(text: '1.4.1');
  final _versionCodeCtrl = TextEditingController(text: '34');
  final _releaseNotesCtrl = TextEditingController(
    text: '• Performance improvements\n• Bug fixes and UI enhancements',
  );

  bool _isMandatory = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  int _selectedFileSize = 0;

  List<Map<String, dynamic>> _releases = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchReleases();
  }

  @override
  void dispose() {
    _versionNameCtrl.dispose();
    _versionCodeCtrl.dispose();
    _releaseNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchReleases() async {
    setState(() => _isLoadingHistory = true);
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('app_updates')
          .select()
          .order('version_code', ascending: false);
      if (mounted) {
        setState(() {
          _releases = List<Map<String, dynamic>>.from(res);
          _isLoadingHistory = false;
          if (_releases.isNotEmpty) {
            final latest = _releases.first;
            final latestCode = (latest['version_code'] as num?)?.toInt() ?? 34;
            final latestName = latest['version_name']?.toString() ?? '1.4.1';
            _versionCodeCtrl.text = '${latestCode + 1}';
            final parts = latestName.split('.');
            if (parts.length == 3) {
              final patch = int.tryParse(parts[2]) ?? 0;
              _versionNameCtrl.text = '${parts[0]}.${parts[1]}.${patch + 1}';
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _pickApkFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
          _selectedFileSize = file.size;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File picker error: $e'),
            backgroundColor: AdminTheme.statusDanger,
          ),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _publishRelease() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an APK file to upload.'),
          backgroundColor: AdminTheme.statusPending,
        ),
      );
      return;
    }

    final versionName = _versionNameCtrl.text.trim();
    final versionCode = int.tryParse(_versionCodeCtrl.text.trim()) ?? 0;
    final notes = _releaseNotesCtrl.text.trim();

    final client = Supabase.instance.client;

    // 1. Pre-check if Version Name or Version Code is already published
    try {
      final existing = await client
          .from('app_updates')
          .select('id, version_name, version_code')
          .or('version_code.eq.$versionCode,version_name.eq.$versionName')
          .maybeSingle();

      if (existing != null) {
        final existingCode = existing['version_code'];
        final existingName = existing['version_name'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Release v$existingName (Version Code: $existingCode) already exists! Please increment to a higher Version Name and Version Code.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AdminTheme.statusPending,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    } catch (_) {
      // If pre-check fails (e.g. offline), continue to upload
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
    });

    try {
      final storagePath = 'StudentHub-v$versionName-$versionCode.apk';

      // 2. Upload APK to Supabase Storage 'app_releases' bucket
      setState(() => _uploadProgress = 0.4);
      await client.storage.from('app_releases').uploadBinary(
            storagePath,
            _selectedFileBytes!,
            fileOptions: const FileOptions(
              contentType: 'application/vnd.android.package-archive',
              upsert: true,
            ),
          );

      setState(() => _uploadProgress = 0.8);
      final apkUrl = client.storage.from('app_releases').getPublicUrl(storagePath);

      // 3. Insert record into app_updates table
      await client.from('app_updates').insert({
        'version_name': versionName,
        'version_code': versionCode,
        'apk_url': apkUrl,
        'file_size_bytes': _selectedFileSize,
        'release_notes': notes,
        'is_mandatory': _isMandatory,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 4. Send instant Realtime broadcast to all connected mobile clients
      try {
        await client.channel('app_updates_realtime').sendBroadcastMessage(
          event: 'new_app_release',
          payload: {
            'id': 'release_$versionCode',
            'version_name': versionName,
            'version_code': versionCode,
            'apk_url': apkUrl,
            'file_size_bytes': _selectedFileSize,
            'release_notes': notes,
            'is_mandatory': _isMandatory,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
      } catch (_) {}

      // 5. Send individual broadcast push notification and save to in-app bell
      try {
        final broadcastId = 'announcement_update_$versionCode';
        await client.from('broadcasts').upsert({
          'id': broadcastId,
          'title': 'App Update: v$versionName',
          'body': "What's new:\n$notes",
          'branch': 'ALL',
          'year': 'ALL',
          'author_name': 'Admin',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        if (mounted) {
          final adminService = Provider.of<AdminSupabaseService>(context, listen: false);
          await adminService.sendBroadcastAnnouncement(
            title: 'App Update: v$versionName',
            body: "What's new:\n$notes",
            customId: broadcastId,
          );
        }
      } catch (e) {
        debugPrint('App update broadcast notification failed: $e');
      }

      setState(() {
        _uploadProgress = 1.0;
        _isUploading = false;
        _selectedFileBytes = null;
        _selectedFileName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚀 Release v$versionName ($versionCode) published successfully!'),
            backgroundColor: AdminTheme.statusOnline,
          ),
        );
        _fetchReleases();
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        String friendlyError = 'Upload failed: $e';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('23505') ||
            errStr.contains('unique') ||
            errStr.contains('already exists')) {
          friendlyError =
              '⚠️ Version code $versionCode or version v$versionName already exists! Please bump the Version Code and Version Name before publishing.';
        } else if (errStr.contains('413') ||
            errStr.contains('too large') ||
            errStr.contains('entitytoolarge')) {
          friendlyError =
              '⚠️ APK package exceeds upload limit. Please upload the 64-bit split APK (e.g. arm64-v8a ~29MB).';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError),
            backgroundColor: AdminTheme.statusDanger,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AdminTheme.primaryLight,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Releases & OTA Updates',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Deploy Over-The-Air APK updates directly to all StudentHub user devices',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Main 2-Column Content Layout (Upload Form & History)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isDesktop = constraints.maxWidth > 900;
                return Flex(
                  direction: isDesktop ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload Card
                    Expanded(
                      flex: isDesktop ? 6 : 0,
                      child: _buildUploadCard(),
                    ),
                    if (isDesktop) const SizedBox(width: 24),
                    if (!isDesktop) const SizedBox(height: 24),

                    // Releases History Card
                    Expanded(
                      flex: isDesktop ? 5 : 0,
                      child: _buildHistoryCard(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminTheme.borderDark),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Publish New App Release',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),

            // APK File Selector Dropzone
            GestureDetector(
              onTap: _isUploading ? null : _pickApkFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedFileName != null
                        ? AdminTheme.primaryLight
                        : AdminTheme.borderDark,
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFileName != null
                          ? Icons.android_rounded
                          : Icons.cloud_upload_outlined,
                      size: 40,
                      color: _selectedFileName != null
                          ? AdminTheme.primaryLight
                          : Colors.white54,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedFileName ?? 'Click to Select Release APK File (.apk)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedFileName != null
                            ? Colors.white
                            : Colors.white70,
                      ),
                    ),
                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Size: ${_formatBytes(_selectedFileSize)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AdminTheme.primaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Version Name & Version Code Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _versionNameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Version Name (e.g. 1.4.1)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: AdminTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AdminTheme.borderDark),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter version name' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _versionCodeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Version Code (e.g. 34)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: AdminTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AdminTheme.borderDark),
                      ),
                    ),
                    validator: (v) =>
                        v == null || int.tryParse(v) == null ? 'Enter integer' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Release Notes Text Area
            TextFormField(
              controller: _releaseNotesCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Release Notes (What\'s New)',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: AdminTheme.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AdminTheme.borderDark),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter release notes' : null,
            ),
            const SizedBox(height: 16),

            // Mandatory Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Mandatory Update (Forces user to install)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              value: _isMandatory,
              activeTrackColor: AdminTheme.primary,
              onChanged: (val) => setState(() => _isMandatory = val),
            ),
            const SizedBox(height: 18),

            // Upload Progress Bar
            if (_isUploading) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: AdminTheme.surfaceDark,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AdminTheme.primaryLight),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Uploading APK package to CDN storage... ${(_uploadProgress * 100).toInt()}%',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isUploading ? null : _publishRelease,
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.rocket_launch_rounded, size: 20),
                label: Text(
                  _isUploading ? 'Publishing Release...' : 'Publish Release & Broadcast',
                  style: GoogleFonts.inter(
                    fontSize: 14,
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

  Widget _buildHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Published Releases',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: _fetchReleases,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AdminTheme.primaryLight),
              ),
            )
          else if (_releases.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded,
                        size: 40, color: Colors.white38),
                    const SizedBox(height: 10),
                    Text(
                      'No releases published yet',
                      style: GoogleFonts.inter(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _releases.length,
              separatorBuilder: (context, index) => const Divider(
                color: AdminTheme.borderDark,
                height: 24,
              ),
              itemBuilder: (ctx, idx) {
                final rel = _releases[idx];
                final versionName = rel['version_name'] ?? '1.0.0';
                final versionCode = rel['version_code'] ?? 1;
                final sizeBytes = rel['file_size_bytes'] ?? 0;
                final isMandatory = rel['is_mandatory'] == true;
                final dateStr = rel['created_at'] != null
                    ? rel['created_at'].toString().split('T').first
                    : '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AdminTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AdminTheme.primaryLight.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'v$versionName ($versionCode)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AdminTheme.primaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isMandatory)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AdminTheme.statusDanger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'MANDATORY',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AdminTheme.statusDanger,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          '$dateStr • ${_formatBytes(sizeBytes)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rel['release_notes'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
