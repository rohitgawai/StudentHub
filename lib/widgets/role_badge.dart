import 'package:flutter/material.dart';
import '../models/user_model.dart';

class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool isCompact;

  const RoleBadge({
    super.key,
    required this.role,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (role == UserRole.student) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    switch (role) {
      case UserRole.eventHost:
        color = isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6);
        break;
      case UserRole.faculty:
        color = isDark ? const Color(0xFFD8B4FE) : const Color(0xFFAF52DE);
        break;
      case UserRole.admin:
        color = isDark ? const Color(0xFFF472B6) : const Color(0xFFAF52DE);
        break;
      case UserRole.student:
        color = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);
        break;
    }

    return Text(
      '• ${role.displayName}',
      style: TextStyle(
        fontSize: isCompact ? 11.5 : 12.5,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.2,
      ),
    );
  }
}
