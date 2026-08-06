import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/role_request_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/role_badge.dart';
import '../widgets/post_card.dart';
import '../widgets/role_request_modal.dart';
import '../widgets/non_coder_config_editor.dart';
import 'dashboards/admin_dashboard_screen.dart';
import 'dashboards/faculty_dashboard_screen.dart';
import 'dashboards/event_host_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;
    final cfg = dataService.config;

    final savedPosts = dataService.posts.where((p) => user.savedPostIds.contains(p.id)).toList();
    final registeredEvents = dataService.posts.where((p) => user.registeredEventIds.contains(p.id)).toList();
    final myRoleRequests = dataService.roleRequests.where((r) => r.userId == user.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Non-Coder Config Manager',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const NonCoderConfigEditor()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: NetworkImage(user.avatarUrl),
                      child: const Icon(Icons.person, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (user.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 18, color: Colors.blue),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.studentOrEmployeeId,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.department} • ${user.year}',
                            style: TextStyle(fontSize: 12, color: cfg.primaryColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Roles Badges Row
                Row(
                  children: [
                    const Text('Assigned Roles: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Wrap(
                      spacing: 6,
                      children: user.roles.map((r) => RoleBadge(role: r, isCompact: true)).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Quick Action Buttons (Apply for Role / Dashboards)
                Row(
                  children: [
                    if (cfg.allowRoleSelfApplication)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const RoleRequestModal(),
                            );
                          },
                          icon: const Icon(Icons.add_moderator, size: 16),
                          label: const Text('Apply for Role', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (ctx) => const NonCoderConfigEditor()),
                          );
                        },
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Non-Coder Config', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),

                // Role Dashboards shortcuts if permitted
                if (user.hasRole(UserRole.admin) || user.hasRole(UserRole.faculty) || user.hasRole(UserRole.eventHost)) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (user.hasRole(UserRole.admin))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: const Icon(Icons.admin_panel_settings, size: 16, color: Colors.purple),
                              label: const Text('Admin Dashboard'),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminDashboardScreen())),
                            ),
                          ),
                        if (user.hasRole(UserRole.faculty))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: const Icon(Icons.menu_book, size: 16, color: Colors.blue),
                              label: const Text('Faculty Dashboard'),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FacultyDashboardScreen())),
                            ),
                          ),
                        if (user.hasRole(UserRole.eventHost))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: const Icon(Icons.event, size: 16, color: Colors.orange),
                              label: const Text('Event Host Dashboard'),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const EventHostDashboardScreen())),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Role Requests Status Box
                if (myRoleRequests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Role Application Statuses:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ...myRoleRequests.map((req) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Text('${req.requestedRole.displayName}: ', style: const TextStyle(fontSize: 11)),
                              _buildStatusBadge(req.status),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Tabs: Saved Posts & Registered Events
          TabBar(
            controller: tabController,
            labelColor: cfg.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Saved Posts (${savedPosts.length})'),
              Tab(text: 'Registered Events (${registeredEvents.length})'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _buildList(savedPosts, 'No saved posts yet. Tap bookmark on feed posts!'),
                _buildList(registeredEvents, 'No registered events yet.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(RoleRequestStatus status) {
    Color color;
    String label;
    switch (status) {
      case RoleRequestStatus.pending:
        color = Colors.orange;
        label = 'Pending Review';
        break;
      case RoleRequestStatus.approved:
        color = Colors.green;
        label = 'Approved';
        break;
      case RoleRequestStatus.rejected:
        color = Colors.red;
        label = 'Rejected';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildList(List posts, String emptyMsg) {
    if (posts.isEmpty) {
      return Center(
        child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: posts.length,
      itemBuilder: (ctx, idx) => PostCard(post: posts[idx]),
    );
  }
}
