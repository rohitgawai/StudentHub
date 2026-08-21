import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateModal extends StatefulWidget {
  final AppUpdateInfo update;

  const UpdateModal({super.key, required this.update});

  @override
  State<UpdateModal> createState() => _UpdateModalState();
}

class _UpdateModalState extends State<UpdateModal> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      await UpdateService.instance.downloadAndInstall(
        update: widget.update,
        onProgress: (progress, downloaded, total) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _downloadedBytes = downloaded;
              _totalBytes = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMandatory = widget.update.isMandatory;
    final primaryColor = isMandatory
        ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706))
        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF0038D8));

    return PopScope(
      canPop: !isMandatory && !_isDownloading,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle (only for non-mandatory)
            if (!isMandatory)
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )
            else
              const SizedBox(height: 4),
            const SizedBox(height: 16),

            // Header Badge Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isMandatory ? Icons.warning_amber_rounded : Icons.system_update_rounded,
                    color: primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isMandatory ? 'Mandatory Update' : 'New Update Available',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'v${widget.update.versionName}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isMandatory
                            ? 'Required to continue using StudentHub'
                            : 'Current: v${UpdateService.currentVersionName} • Size: ${_formatBytes(widget.update.fileSizeBytes)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Release Notes Container
            Text(
              "What's New in v${widget.update.versionName}:",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
                ),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.update.releaseNotes.trim(),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress Bar / Error
            if (_isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 7,
                  backgroundColor: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _progress >= 1.0
                        ? '🚀 Launching Package Installer...'
                        : 'Downloading update... ${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes > 0 ? _totalBytes : widget.update.fileSizeBytes)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11.5, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                if (!isMandatory && !_isDownloading) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: isMandatory ? 1 : 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isDownloading ? null : _startUpdate,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      _isDownloading
                          ? 'Downloading...'
                          : (_errorMessage != null ? 'Retry Download' : 'Update Now'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
