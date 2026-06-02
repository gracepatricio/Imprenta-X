import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../services/file_utils.dart' as file_utils;

/// Chip displayed on job-queue cards. Tapping opens [FileViewerDialog].
class DesignFileChip extends StatelessWidget {
  final String name;
  final String url;
  const DesignFileChip({super.key, required this.name, required this.url});

  IconData get _icon {
    final ext = name.split('.').last.toLowerCase();
    if ({'jpg', 'jpeg', 'png'}.contains(ext)) return Icons.image_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => FileViewerDialog(name: name, url: url),
      ),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 12, color: Colors.blue.shade300),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                name,
                style: TextStyle(color: Colors.blue.shade300, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 11, color: Colors.blue.shade300),
          ],
        ),
      ),
    );
  }
}

/// Reads [file_urls] + [file_names] from a products list and renders chips.
class DesignFilesSection extends StatelessWidget {
  final List products;
  const DesignFilesSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final files = <({String name, String url})>[];
    for (final p in products) {
      final urls  = List<String>.from(p['file_urls']  as List? ?? []);
      final names = List<String>.from(p['file_names'] as List? ?? []);
      for (int i = 0; i < urls.length; i++) {
        if (urls[i].isEmpty) continue;
        files.add((
          name: i < names.length && names[i].isNotEmpty
              ? names[i]
              : 'File ${i + 1}',
          url: urls[i],
        ));
      }
    }
    if (files.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Design Files',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: files
                .map((f) => DesignFileChip(name: f.name, url: f.url))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Dialog showing a preview (images) or file icon (PDF/PSD/AI),
/// plus "Open in New Tab" and "Download" buttons.
/// Download uses a fetch→blob approach on web so cross-origin files
/// are saved locally rather than just opened in a new tab.
class FileViewerDialog extends StatefulWidget {
  final String name;
  final String url;
  const FileViewerDialog({super.key, required this.name, required this.url});

  @override
  State<FileViewerDialog> createState() => _FileViewerDialogState();
}

class _FileViewerDialogState extends State<FileViewerDialog> {
  bool _downloading = false;

  String get _ext => widget.name.split('.').last.toLowerCase();
  bool get _isImage => {'jpg', 'jpeg', 'png'}.contains(_ext);
  bool get _isPdf => _ext == 'pdf';

  IconData get _fileIcon {
    if (_isImage) return Icons.image_rounded;
    if (_isPdf) return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color get _fileColor {
    if (_isImage) return Colors.greenAccent;
    if (_isPdf) return Colors.redAccent;
    return Colors.blueAccent;
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await file_utils.downloadFile(widget.url, widget.name);
    } catch (_) {}
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Row(
                children: [
                  Icon(_fileIcon, color: _fileColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Preview ──────────────────────────────────────────────────────
              if (_isImage)
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      widget.url,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: AppTheme.gold,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, st) => _filePlaceholder(),
                    ),
                  ),
                )
              else
                _filePlaceholder(),

              const SizedBox(height: 16),

              // ── Buttons ──────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          file_utils.openFileInNewTab(widget.url),
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                      ),
                      label: const Text('Open in New Tab'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _downloading ? null : _download,
                      icon: _downloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 16),
                      label: Text(_downloading ? 'Downloading…' : 'Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filePlaceholder() => Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_fileIcon, color: _fileColor, size: 48),
            const SizedBox(height: 8),
            Text(
              _ext.toUpperCase(),
              style: TextStyle(
                color: _fileColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}
