import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/form_models.dart';
import '../models/post_model.dart';

enum ExportFormat { csv, pdf }

const MethodChannel _mediaChannel = MethodChannel('student_hub/mediastore');

String _formatExportDate(DateTime dt) {
  String pad(int v) => v.toString().padLeft(2, '0');
  return '${pad(dt.day)}/${pad(dt.month)}/${dt.year} ${pad(dt.hour)}:${pad(dt.minute)}';
}

String _safeFileName(String title) {
  final cleaned = title
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return cleaned.isEmpty ? 'post' : cleaned;
}

/// Q-column headers: question labels from the attached form when available,
/// otherwise generic Q1..QN for quick registrations.
List<String> _answerHeaders(PostModel post, List<FormSubmission> subs) {
  final form = post.form;
  if (form != null && form.fields.isNotEmpty) {
    return form.fields
        .where((f) => !f.isHeader && f.label.trim().isNotEmpty)
        .map((f) => f.label.trim())
        .toList();
  }
  final keys = <String>{};
  for (final s in subs) {
    keys.addAll(s.answers.keys.where((k) => k.trim().isNotEmpty));
  }
  // Sorted so the column order is deterministic for the same data on every
  // device / Android version.
  final sorted = keys.toList()..sort();
  return sorted;
}

/// Answers keyed by question label -> value (fall back to field ids).
Map<String, dynamic> _labelsToAnswers(PostModel post, FormSubmission s) {
  final resolved = <String, dynamic>{};
  final form = post.form;
  if (form == null) {
    s.answers.forEach((k, v) => resolved[k] = v);
    return resolved;
  }
  final byId = {for (final f in form.fields) f.id: f};
  s.answers.forEach((key, value) {
    final field = byId[key];
    resolved[field?.label.isNotEmpty == true ? field!.label : key] = value;
  });
  return resolved;
}

String _stringify(dynamic value) {
  if (value == null) return '';
  if (value is List) return value.join(', ');
  return value.toString();
}

/// Display text for every attached link (`label: url`), one per line.
String _attachedLinkText(PostModel post) => post.links
    .map((l) => l.label.isEmpty ? l.url : '${l.label}: ${l.url}')
    .join('\n');

String buildRegistrantCsv({
  required PostModel post,
  required List<FormSubmission> submissions,
}) {
  final hasForm = post.form != null && post.form!.fields.isNotEmpty;
  // Link-only events (no form) export the attached link instead of answers.
  // When a no-form post has answered submissions (e.g. the host removed the
  // form after collecting responses), the answer keys are appended so no
  // data is ever lost.
  final linkText = _attachedLinkText(post);
  final headers = hasForm
      ? _answerHeaders(post, submissions)
      : [
          if (post.links.isNotEmpty) 'Link Attached',
          ..._answerHeaders(post, submissions),
        ];
  // UTF-8 BOM so Excel/LibreOffice detect the encoding instead of garbling
  // non-ASCII characters.
  final buf = StringBuffer('\uFEFF');

  String escapeCell(dynamic value) {
    if (value == null) return '""';
    String str;
    if (value is List) {
      str = value.map((e) => e?.toString() ?? '').join('; ');
    } else {
      str = value.toString();
    }
    // Clean whitespace and remove newlines/tabs so each record stays strictly in its row
    str = str
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ')
        .trim();
    // RFC 4180 standard quote escaping
    str = str.replaceAll('"', '""');
    return '"$str"';
  }

  // Header row
  final headerCells = [
    'Sr. No.',
    'Full Name',
    'Student ID',
    'Department',
    'Academic Year',
    'Mobile Number',
    'Registration Date',
    ...headers,
  ];
  buf.write('${headerCells.map(escapeCell).join(',')}\r\n');

  // Data rows
  for (var i = 0; i < submissions.length; i++) {
    final s = submissions[i];
    final answers = _labelsToAnswers(post, s);
    final rowCells = [
      '${i + 1}',
      s.name.isNotEmpty ? s.name : 'N/A',
      s.studentOrEmployeeId.isNotEmpty ? s.studentOrEmployeeId : 'N/A',
      s.department.isNotEmpty ? s.department : 'N/A',
      s.year.isNotEmpty ? s.year : 'N/A',
      s.mobileNumber.isNotEmpty ? s.mobileNumber : 'N/A',
      _formatExportDate(s.submittedAt),
      ...headers.map((h) =>
          h == 'Link Attached' ? linkText : _stringify(answers[h])),
    ];
    buf.write('${rowCells.map(escapeCell).join(',')}\r\n');
  }

  return buf.toString();
}

Future<Uint8List> buildRegistrantPdf({
  required PostModel post,
  required List<FormSubmission> submissions,
  String collegeName = 'StudentHub',
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Text(
        '$collegeName · ${post.isEvent ? 'Event Registration Report' : 'Form Responses'}',
        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          post.title,
          style: pw.TextStyle(
            fontSize: 17,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${post.department} · Generated ${_formatExportDate(DateTime.now())} · '
          '${submissions.length} ${post.isEvent ? 'registrations' : 'responses'}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        // The attached link is a property of the post, not of each
        // registrant. Print it once here so the table below stays clean and
        // renders identically on every device / PDF viewer.
        if (post.links.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            'Attached link: ${_attachedLinkText(post)}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Name',
            'MIT ID',
            'Dept',
            'Year',
            'Mobile',
            'Submitted',
            'Answers',
          ],
          data: submissions.map((s) {
            final answers = _labelsToAnswers(post, s);
            final hasForm = post.form != null && post.form!.fields.isNotEmpty;
            final answerText = hasForm
                ? answers.entries
                    .map((e) => '${e.key}: ${_stringify(e.value)}')
                    .join('\n')
                : '';
            return [
              s.name,
              s.studentOrEmployeeId,
              s.department,
              s.year,
              s.mobileNumber,
              _formatExportDate(s.submittedAt),
              answerText.isEmpty ? '—' : answerText,
            ];
          }).toList(),
          border: pw.TableBorder.all(
            color: PdfColors.grey400,
            width: 0.5,
          ),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.blueGrey700,
          ),
          cellStyle: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey900),
          cellPadding: const pw.EdgeInsets.all(5),
        ),
        if (submissions.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'No ${post.isEvent ? 'registrations' : 'responses'} yet.',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
      ],
    ),
  );
  return doc.save();
}

/// Resolves the user's public Downloads directory across Android, iOS & Desktop.
Future<Directory> _getDownloadsDir() async {
  try {
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        return downloadDir;
      }
    }
    final dir = await getDownloadsDirectory();
    if (dir != null && await dir.exists()) {
      return dir;
    }
  } catch (_) {}
  try {
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) return extDir;
  } catch (_) {}
  return await getApplicationDocumentsDirectory();
}

/// Saves the CSV or PDF export directly to the device's Downloads directory.
///
/// Android strategy (scoped storage safe):
/// 1. MediaStore insert (Android 10+) — instant, lands in real Downloads,
///    no permission and no dialog.
/// 2. Direct file copy (Android 9 & below) — legacy storage write.
/// 3. System "Save" dialog (SAF) — guaranteed fallback on every Android
///    version if the fast paths are unavailable.
///
/// Returns the saved file plus the real display file name (the SAF path can
/// end in a numeric document id instead of the file name).
Future<({File file, String fileName})> saveRegistrantExportDirectly({
  required PostModel post,
  required List<FormSubmission> submissions,
  required ExportFormat format,
  String collegeName = 'StudentHub',
}) async {
  final base = _safeFileName(post.title);
  final ext = format == ExportFormat.csv ? 'csv' : 'pdf';
  final fileName = '${base}_registrations.$ext';

  if (Platform.isAndroid) {
    try {
      final bytes = format == ExportFormat.csv
          ? Uint8List.fromList(
              utf8.encode(buildRegistrantCsv(post: post, submissions: submissions)),
            )
          : await buildRegistrantPdf(
              post: post,
              submissions: submissions,
              collegeName: collegeName,
            );
      final uri = await _mediaChannel.invokeMethod<String>('insertDownload', {
        'name': fileName,
        'bytes': bytes,
      });
      if (uri != null) {
        return (file: File(uri), fileName: fileName);
      }
    } catch (e) {
      debugPrint('MediaStore insert failed ($e), falling back');
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');

    if (format == ExportFormat.csv) {
      await tempFile.writeAsString(
        buildRegistrantCsv(post: post, submissions: submissions),
      );
    } else {
      await tempFile.writeAsBytes(
        await buildRegistrantPdf(
          post: post,
          submissions: submissions,
          collegeName: collegeName,
        ),
      );
    }

    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final out = await tempFile.copy('${downloadDir.path}/$fileName');
        return (file: out, fileName: fileName);
      }
    } catch (e) {
      debugPrint('Direct Downloads copy failed ($e), using SAF picker');
    }

    final picked = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: await tempFile.readAsBytes(),
      type: FileType.any,
    );
    if (picked != null) return (file: File(picked), fileName: fileName);
    throw Exception('Export cancelled by user');
  }

  final dir = await _getDownloadsDir();
  final file = File('${dir.path}/$fileName');

  if (format == ExportFormat.csv) {
    await file.writeAsString(
      buildRegistrantCsv(post: post, submissions: submissions),
    );
  } else {
    final bytes = await buildRegistrantPdf(
      post: post,
      submissions: submissions,
      collegeName: collegeName,
    );
    await file.writeAsBytes(bytes);
  }
  return (file: file, fileName: fileName);
}

/// Writes the export to a temp file ready for sharing.
Future<File> writeRegistrantExport({
  required PostModel post,
  required List<FormSubmission> submissions,
  required ExportFormat format,
  String collegeName = 'StudentHub',
}) async {
  final dir = await getTemporaryDirectory();
  final base = _safeFileName(post.title);
  final file = File(
    '${dir.path}/${base}_${format.name == 'csv' ? 'registrations.csv' : 'registrations.pdf'}',
  );
  if (format == ExportFormat.csv) {
    await file.writeAsString(
      buildRegistrantCsv(post: post, submissions: submissions),
    );
  } else {
    final bytes = await buildRegistrantPdf(
      post: post,
      submissions: submissions,
      collegeName: collegeName,
    );
    await file.writeAsBytes(bytes);
  }
  return file;
}