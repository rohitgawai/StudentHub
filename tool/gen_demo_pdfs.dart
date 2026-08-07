import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main() {
  const outDir = 'assets/pdfs';
  final dir = Directory(outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final docs = <String, List<String>>{
    'mid_sem_exam_schedule.pdf': [
      'Mid-Semester Exam Schedule - Autumn 2026',
      '',
      'Attention: CSE and IT Third and Final Year Students',
      'Examinations begin Monday at 09:00 AM in Block C.',
      'Subject-wise timetable is published below.',
      '',
      'CSE - Database Systems: Monday 09:00 AM, Block C',
      'CSE - Operating Systems: Tuesday 09:00 AM, Block C',
      'IT - Computer Networks: Wednesday 09:00 AM, Block C',
      'IT - Software Engineering: Thursday 09:00 AM, Block C',
      '',
      'Carry your hall ticket and college ID.',
      'Contact the Dean Academics office for queries.',
    ],
    'open_elective_syllabus.pdf': [
      'Open Elective Course III - Syllabus Overview',
      '',
      'Final Year students may choose one open elective.',
      'Submit preferences before Friday 5:00 PM.',
      '',
      'Elective A - Cloud Computing: 3 credits, 45 hours',
      'Elective B - Data Analytics: 3 credits, 45 hours',
      'Elective C - Digital Marketing: 3 credits, 45 hours',
      '',
      'Each elective includes a hands-on project component.',
      'Review the student portal for full syllabus details.',
    ],
    'placement_eligibility.pdf': [
      'Placement Drive - Eligibility Details',
      '',
      'Google Cloud and Microsoft technical roles open.',
      'Eligibility: Final Year CSE, IT, ECE students.',
      '',
      'Minimum CGPA required: 7.5',
      'No active backlogs permitted.',
      'Registration closes Friday 5:00 PM.',
      '',
      'Carry updated resumes and prior offer letters.',
      'Contact the Placement Cell for queries.',
    ],
  };

  docs.forEach((name, lines) {
    final bytes = buildPdf(lines);
    File('$outDir/$name').writeAsBytesSync(bytes);
    stdout.writeln('Wrote $outDir/$name (${bytes.length} bytes)');
  });
}

Uint8List buildPdf(List<String> lines) {
  final content = StringBuffer()
    ..writeln('BT')
    ..writeln('/F1 16 Tf')
    ..writeln('72 740 Td');
  for (final line in lines) {
    if (line.isEmpty) {
      content.writeln('T* T*');
    } else {
      content.writeln('(${_escape(line)}) Tj');
      content.writeln('T*');
    }
  }
  content.writeln('ET');
  final contentStr = content.toString();
  final contentLen = utf8.encode(contentStr).length;

  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length $contentLen >>\nstream\n$contentStr\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];

  final sb = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(utf8.encode(sb.toString()).length);
    sb.writeln('${i + 1} 0 obj');
    sb.writeln(objects[i]);
    sb.writeln('endobj');
  }
  final xrefOffset = utf8.encode(sb.toString()).length;
  sb.writeln('xref');
  sb.writeln('0 ${objects.length + 1}');
  sb.writeln('0000000000 65535 f ');
  for (final off in offsets) {
    sb.writeln('${off.toString().padLeft(10, '0')} 00000 n ');
  }
  sb.writeln('trailer');
  sb.writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>');
  sb.writeln('startxref');
  sb.writeln('$xrefOffset');
  sb.writeln('%%EOF');
  return utf8.encode(sb.toString());
}

String _escape(String text) => text.replaceAll('\\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
