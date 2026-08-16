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
    return form.fields.where((f) => !f.isHeader).map((f) => f.label).toList();
  }
  final maxAnswers = subs
      .map((s) => s.answers.length)
      .fold<int>(0, (a, b) => a > b ? a : b);
  return List.generate(maxAnswers, (i) => 'Q${i + 1}');
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

String buildRegistrantCsv({
  required PostModel post,
  required List<FormSubmission> submissions,
}) {
  final headers = _answerHeaders(post, submissions);
  // UTF-8 BOM so Excel/LibreOffice detect the encoding instead of garbling
  // non-ASCII characters.
  final buf = StringBuffer('\uFEFF');
  // Cells are clipped to a single line of sane length: multi-line or very
  // long content overflows into neighbouring columns and visually "merges"
  // with them in Excel. The PDF export keeps the full text.
  const int maxCellLength = 120;
  List<String> esc(Iterable<String> cells) => cells.map((c) {
        final safe = c
            .replaceAll('"', '""')
            .replaceAll(RegExp(r'\r?\n'), ' | ')
            .replaceAll('\t', ' ');
        final clipped = safe.length > maxCellLength
            ? '${safe.substring(0, maxCellLength)}…'
            : safe;
        return '"$clipped"';
      }).toList();

  buf.writeln(
    esc([
      'Name',
      'MIT ID',
      'Department',
      'Year',
      'Mobile Number',
      'Submitted At',
      ...headers,
    ]).join(','),
  );
  for (final s in submissions) {
    final answers = _labelsToAnswers(post, s);
    buf.writeln(
      esc([
        s.name,
        s.studentOrEmployeeId,
        s.department,
        s.year,
        s.mobileNumber,
        _formatExportDate(s.submittedAt),
        ...headers.map((h) => _stringify(answers[h])),
      ]).join(','),
    );
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
            final answerText = answers.entries
                .map((e) => '${e.key}: ${_stringify(e.value)}')
                .join('\n');
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