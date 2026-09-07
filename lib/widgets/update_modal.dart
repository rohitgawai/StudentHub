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
    final isAlreadyUpToDate = UpdateService.isVersionInstalled(
      versionCode: widget.update.versionCode,
      versionName: widget.update.versionName,
    );
    final primaryColor = isAlreadyUpToDate
        ? const Color(0xFF10B981)
        : (isMandatory
            ? const Color(0xFFF59E0B)
            : const Color(0xFF2563EB));

    return PopScope(
      canPop: !isMandatory && !_isDownloading,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Designed atmospheric backdrop with decorative gradient orbs & floating campus watermarks
            Positioned.fill(
              child: GestureDetector(
                onTap: (!isMandatory && !_isDownloading)
                    ? () => Navigator.of(context).pop()
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF0B0F19).withValues(alpha: 0.94),
                              const Color(0xFF030712).withValues(alpha: 0.98),
                            ]
                          : [
                              const Color(0xFFE0E7FF).withValues(alpha: 0.92),
                              const Color(0xFFF8FAFC).withValues(alpha: 0.96),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            // Decorative Glowing Orb 1 (Top Left)
            Positioned(
              top: -60,
              left: -60,
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isAlreadyUpToDate
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6))
                            .withValues(alpha: isDark ? 0.35 : 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Decorative Glowing Orb 2 (Bottom Right)
            Positioned(
              bottom: -70,
              right: -70,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isAlreadyUpToDate
                                ? const Color(0xFF059669)
                                : const Color(0xFF7C3AED))
                            .withValues(alpha: isDark ? 0.32 : 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Subtle Floating Campus Design Icons in the Background
            Positioned(
              top: 80,
              right: 40,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: (isDark ? Colors.white : Colors.blue).withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: 30,
              child: IgnorePointer(
                child: Icon(
                  Icons.school_rounded,
                  size: 64,
                  color: (isDark ? Colors.white : Colors.purple).withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              top: 200,
              left: 45,
              child: IgnorePointer(
                child: Icon(
                  Icons.rocket_launch_rounded,
                  size: 40,
                  color: (isDark ? Colors.white : Colors.indigo).withValues(alpha: 0.06),
                ),
              ),
            ),

            // Layer 2: Centered Rich Presentation Card
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141A) : Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: isDark ? const Color(0xFF282834) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Glowing Hero Rocket / Verified Badge
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isAlreadyUpToDate
                                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                  : (isMandatory
                                      ? [const Color(0xFFF59E0B), const Color(0xFFEA580C)]
                                      : [const Color(0xFF2563EB), const Color(0xFF7C3AED)]),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            isAlreadyUpToDate
                                ? Icons.verified_rounded
                                : (isMandatory
                                    ? Icons.warning_amber_rounded
                                    : Icons.rocket_launch_rounded),
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          isAlreadyUpToDate
                              ? 'You’re Up to Date!'
                              : (isMandatory ? 'Mandatory Update Required' : 'New Update Available'),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),

                        // Version & Size / Status Badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'v${widget.update.versionName} (Build ${widget.update.versionCode})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            if (isAlreadyUpToDate) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Latest Version Installed',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (widget.update.fileSizeBytes > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF22222C) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Size: ${_formatBytes(widget.update.fileSizeBytes)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (isAlreadyUpToDate) ...[
                          const SizedBox(height: 6),
                          Text(
                            'StudentHub is running the newest release with all active features & security patches.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Release Notes Box
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "What's New in this Version:",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 140),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0E0E14) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF242430) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              widget.update.releaseNotes.trim(),
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Progress Bar / Error section (Only shown during active updates)
                        if (!isAlreadyUpToDate && _isDownloading) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progress > 0 ? _progress : null,
                              minHeight: 8,
                              backgroundColor: isDark ? const Color(0xFF242430) : const Color(0xFFE2E8F0),
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

                        if (!isAlreadyUpToDate && _errorMessage != null) ...[
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
                        if (isAlreadyUpToDate) ...[
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text(
                                  'Great, Got it!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              if (!isMandatory && !_isDownloading) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      side: BorderSide(
                                        color: isDark ? const Color(0xFF2E2E3C) : Colors.grey.shade300,
                                      ),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text(
                                      'Remind Later',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                flex: isMandatory ? 1 : 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isMandatory
                                          ? [const Color(0xFFF59E0B), const Color(0xFFEA580C)]
                                          : [const Color(0xFF2563EB), const Color(0xFF7C3AED)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
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
                              ),
                            ],
                          ),
                        ],
                      ],
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
