import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/role_request_model.dart';
import '../../models/user_model.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/role_badge.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final roleReqs = dataService.roleRequests;
    final pendingReqs = roleReqs.where((r) => r.status == RoleRequestStatus.pending).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🛡️ Admin Dashboard'),
          backgroundColor: Colors.purple.shade900,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.purple.shade200,
            tabs: [
              Tab(text: 'Role Requests (${pendingReqs.length})'),
              const Tab(text: 'Post Moderation'),
              const Tab(text: 'Analytics & System'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRoleRequestsTab(context, dataService, pendingReqs),
            _buildModerationTab(context, dataService),
            _buildAnalyticsTab(context, dataService),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleRequestsTab(BuildContext context, MockDataService dataService, List<RoleRequestModel> pendingReqs) {
    if (pendingReqs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 12),
            Text('All role applications have been reviewed!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingReqs.length,
      itemBuilder: (context, index) {
        final req = pendingReqs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      req.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    RoleBadge(role: req.requestedRole, isCompact: true),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'ID: ${req.studentId} • ${req.department}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    if (req.isLimitedAccess && req.expiresAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          'Temporary • expires ${req.expiresAt!.day}/${req.expiresAt!.month}/${req.expiresAt!.year}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: const Text(
                          'Permanent',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Reason: "${req.reason}"',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Reject'),
                      onPressed: () {
                        dataService.updateRoleRequestStatus(req.id, RoleRequestStatus.rejected, 'Incomplete details');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Rejected ${req.userName}\'s request.')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve Role'),
                      onPressed: () {
                        dataService.updateRoleRequestStatus(req.id, RoleRequestStatus.approved, 'Approved by Admin');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Approved ${req.requestedRole.displayName} status for ${req.userName}!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModerationTab(BuildContext context, MockDataService dataService) {
    final posts = dataService.posts;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final p = posts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('By ${p.authorName} (${p.department})'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Inappropriate Post',
              onPressed: () {
                dataService.deletePost(p.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post deleted by Admin moderation.')),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, MockDataService dataService) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMetricCard('Active Registered Users', '1,420 Students & Faculty', Icons.people, Colors.blue),
        _buildMetricCard('Notice Read Rate', '94.2% Average Open Rate', Icons.mark_email_read, Colors.green),
        _buildMetricCard('Event Registrations', '840 Seats Booked This Month', Icons.event_available, Colors.orange),
        _buildMetricCard('Total Published Posts', '${dataService.posts.length} Active Notice Cards', Icons.post_add, Colors.purple),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 24,
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
