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
    Color bg;
    Color text;
    IconData icon;

    switch (role) {
      case UserRole.student:
        bg = const Color(0xFFE2E8F0);
        text = const Color(0xFF334155);
        icon = Icons.school;
        break;
      case UserRole.eventHost:
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFFC2410C);
        icon = Icons.event;
        break;
      case UserRole.faculty:
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        icon = Icons.menu_book;
        break;
      case UserRole.admin:
        bg = const Color(0xFFAF52DE).withOpacity(0.15);
        text = const Color(0xFFAF52DE);
        icon = Icons.verified_user;
        break;
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
            Text(
              role.displayName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 6),
          Text(
            role.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
