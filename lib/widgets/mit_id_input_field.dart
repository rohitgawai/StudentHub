import 'package:flutter/material.dart';

class MitIdInputField extends StatefulWidget {
  final String initialValue;
  final String department;
  final String year;
  final ValueChanged<String> onChanged;

  const MitIdInputField({
    super.key,
    required this.initialValue,
    required this.department,
    required this.year,
    required this.onChanged,
  });

  @override
  State<MitIdInputField> createState() => _MitIdInputFieldState();
}

class _MitIdInputFieldState extends State<MitIdInputField> {
  late TextEditingController yearCtrl;
  late TextEditingController sectionCtrl;
  late TextEditingController groupCtrl;
  late TextEditingController rollCtrl;
  String selectedLevel = 'UG';
  late String deptCode;

  @override
  void initState() {
    super.initState();
    _parseInitialValue();
  }

  @override
  void didUpdateWidget(covariant MitIdInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.department != widget.department) {
      _updateDeptCode();
      _notifyCombined();
    }
  }

  void _updateDeptCode() {
    final d = widget.department.toLowerCase();
    if (d.contains('electronics') || d.contains('ece')) {
      deptCode = 'ECE';
    } else if (d.contains('computer') || d.contains('cse')) {
      deptCode = 'CSE';
    } else if (d.contains('mechanical') || d.contains('mech')) {
      deptCode = 'MECH';
    } else if (d.contains('civil')) {
      deptCode = 'CIVIL';
    } else if (d.contains('information') || d.contains('it')) {
      deptCode = 'IT';
    } else if (d.contains('data') || d.contains('ai')) {
      deptCode = 'AIDS';
    } else {
      deptCode = 'ECE';
    }
  }

  void _parseInitialValue() {
    _updateDeptCode();

    var yr = '21';
    var sec = 'B';
    var grp = '01';
    var lvl = 'UG';
    var rll = '12345';

    if (widget.initialValue.isNotEmpty) {
      final val = widget.initialValue.trim();
      final parts = val.split('-');
      if (parts.isNotEmpty) {
        final firstPart = parts[0];
        if (firstPart.toUpperCase().startsWith('MIT')) {
          final digits = firstPart.substring(3);
          if (digits.isNotEmpty) {
            yr = digits;
          }
        }
      }
      if (parts.length >= 6) {
        sec = parts[1];
        grp = parts[2];
        lvl = parts[3];
        rll = parts[5];
      }
    }

    yearCtrl = TextEditingController(text: yr);
    sectionCtrl = TextEditingController(text: sec);
    groupCtrl = TextEditingController(text: grp);
    rollCtrl = TextEditingController(text: rll);
    selectedLevel = (lvl == 'PG') ? 'PG' : 'UG';
  }

  @override
  void dispose() {
    yearCtrl.dispose();
    sectionCtrl.dispose();
    groupCtrl.dispose();
    rollCtrl.dispose();
    super.dispose();
  }

  void _notifyCombined() {
    final yr = yearCtrl.text.trim();
    final sec = sectionCtrl.text.trim().toUpperCase();
    final grp = groupCtrl.text.trim();
    final rll = rollCtrl.text.trim();
    final full =
        'MIT${yr.isEmpty ? '21' : yr}-${sec.isEmpty ? 'B' : sec}-${grp.isEmpty ? '01' : grp}-$selectedLevel-$deptCode-${rll.isEmpty ? '12345' : rll}';
    widget.onChanged(full);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF818CF8) : Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MIT Unique Identification Number:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),

        // Live Combined ID Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: isDark ? 0.4 : 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.badge_outlined,
                size: 18,
                color: isDark ? const Color(0xFFA1A1AA) : Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              SelectableText(
                'MIT${yearCtrl.text}-${sectionCtrl.text.toUpperCase()}-${groupCtrl.text}-$selectedLevel-$deptCode-${rollCtrl.text}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // OTP / Segmented Box Controls
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Segment 1: MIT Prefix Badge (Fixed)
              _buildBadgeBox('MIT', primaryColor, isDark),

              // Segment 2: Year Code (2 Digits Inputable)
              _buildInputBox(
                controller: yearCtrl,
                width: 50,
                maxLength: 2,
                hint: '21',
                keyboardType: TextInputType.number,
                isDark: isDark,
              ),
              _buildHyphen(),

              // Segment 3: Section (1 Char Inputable)
              _buildInputBox(
                controller: sectionCtrl,
                width: 44,
                maxLength: 1,
                hint: 'B',
                textCapitalization: TextCapitalization.characters,
                isDark: isDark,
              ),
              _buildHyphen(),

              // Segment 4: Group (2 Chars Inputable)
              _buildInputBox(
                controller: groupCtrl,
                width: 52,
                maxLength: 2,
                hint: '01',
                keyboardType: TextInputType.number,
                isDark: isDark,
              ),
              _buildHyphen(),

              // Segment 5: Level Dropdown (UG / PG)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF262626) : Colors.grey.shade400,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLevel,
                    dropdownColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'UG',
                        child: Text(
                          'UG',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'PG',
                        child: Text(
                          'PG',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedLevel = val);
                        _notifyCombined();
                      }
                    },
                  ),
                ),
              ),
              _buildHyphen(),

              // Segment 6: Dept Code Badge (Fixed from Department selection)
              _buildBadgeBox(
                deptCode,
                isDark ? const Color(0xFF60A5FA) : Colors.blueGrey.shade700,
                isDark,
              ),
              _buildHyphen(),

              // Segment 7: Roll Number (5 Digits OTP Box)
              _buildInputBox(
                controller: rollCtrl,
                width: 90,
                maxLength: 5,
                hint: '12345',
                keyboardType: TextInputType.number,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Format auto-generates (e.g. MIT21-B-01-UG-ECE-12345)',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF71717A) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeBox(String label, Color color, bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.5 : 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildHyphen() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '-',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildInputBox({
    required TextEditingController controller,
    required double width,
    required int maxLength,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool isDark = false,
  }) {
    return SizedBox(
      width: width,
      height: 48,
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          fontFamily: 'monospace',
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF71717A) : Colors.grey.shade400,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF262626) : Colors.grey.shade400,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF262626) : Colors.grey.shade400,
            ),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
        ),
        onChanged: (_) => _notifyCombined(),
      ),
    );
  }
}
