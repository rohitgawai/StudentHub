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

    Color color;
    switch (role) {
      case UserRole.eventHost:
        color = const Color(0xFF312E81);
        break;
      case UserRole.faculty:
        color = const Color(0xFFAF52DE);
        break;
      case UserRole.admin:
        color = const Color(0xFFAF52DE);
        break;
      case UserRole.student:
        color = const Color(0xFF64748B);
        break;
    }

    return Text(
      '• ${role.displayName}',
      style: TextStyle(
        fontSize: isCompact ? 11.5 : 12.5,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.2,
      ),
    );
  }
}
