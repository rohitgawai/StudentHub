import 'dart:io';

void main() {
  final dir = Directory('assets/pdfs');
  var failed = false;
  for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf'))) {
    final bytes = f.readAsBytesSync();
    final ok = _isValid(bytes);
    stdout.writeln('${ok ? 'OK  ' : 'FAIL'} ${f.path} (${bytes.length} bytes)');
    if (!ok) failed = true;
  }
  exitCode = failed ? 1 : 0;
}

bool _isValid(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  if (!text.startsWith('%PDF-') || !text.contains('%%EOF')) return false;

  final startRef = RegExp(r'startxref\s+(\d+)').firstMatch(text);
  if (startRef == null) return false;
  final xrefOffset = int.parse(startRef.group(1)!);

  final region = String.fromCharCodes(bytes, xrefOffset);
  final header = RegExp(r'xref\r?\n0 (\d+)').firstMatch(region);
  if (header == null) return false;
  final count = int.parse(header.group(1)!);

  final lines = region.split(RegExp(r'\r?\n'));
  var idx = 0;
  while (idx < lines.length && !lines[idx].trim().startsWith('xref')) {
    idx++;
  }
  idx += 2; // skip 'xref' and the '0 N' line

  for (var obj = 1; obj < count; obj++) {
    final entry = lines[idx + obj].trim().split(RegExp(r'\s+'));
    if (entry.length < 3) return false;
    final off = int.tryParse(entry[0]);
    if (off == null || off >= bytes.length) return false;
    final snippet = String.fromCharCodes(bytes, off, (off + 24).clamp(0, bytes.length));
    if (!snippet.contains('$obj 0 obj')) return false;
  }
  return true;
}