import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';

class OnlineUsersScreen extends StatefulWidget {
  const OnlineUsersScreen({super.key});

  @override
  State<OnlineUsersScreen> createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<AdminSupabaseService>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final filteredUsers = service.onlineUsers.where((u) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.studentId?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.statusOnline.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sensors_rounded, color: AdminTheme.statusOnline, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Real-Time Active Sessions',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Currently ${service.onlineUsers.length} student(s) active on StudentHub',
                    style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Box
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search online students by name, email, or MIT ID...',
              hintStyle: GoogleFonts.inter(color: AdminTheme.textMuted),
              prefixIcon: const Icon(Icons.search, color: AdminTheme.textMuted),
              filled: true,
              fillColor: AdminTheme.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AdminTheme.borderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AdminTheme.borderDark),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Content Grid / List
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: AdminTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No Active Online Students Found',
                          style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'When students open the mobile app, their sessions will appear here live.',
                          style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 3 : 1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 130,
                    ),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AdminTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AdminTheme.statusOnline.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AdminTheme.primary.withOpacity(0.3),
                                  child: Text(
                                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'S',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AdminTheme.statusOnline,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AdminTheme.surfaceCard, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          user.fullName,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (user.isVerifiedStudent)
                                        const Icon(Icons.verified, color: AdminTheme.statusVerified, size: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email,
                                    style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AdminTheme.primary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          user.role.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            color: AdminTheme.primaryLight,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        user.lastSeen != null
                                            ? DateFormat('hh:mm a').format(user.lastSeen!)
                                            : 'Just now',
                                        style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
