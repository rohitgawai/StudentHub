import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/post_model.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/create_event_modal.dart';
import '../../widgets/create_post_modal.dart';

class EventHostDashboardScreen extends StatefulWidget {
  const EventHostDashboardScreen({super.key});

  @override
  State<EventHostDashboardScreen> createState() => _EventHostDashboardScreenState();
}

class _EventHostDashboardScreenState extends State<EventHostDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditDialog(BuildContext context, MockDataService dataService, PostModel post) {
    final titleCtrl = TextEditingController(text: post.title);
    final descCtrl = TextEditingController(text: post.description);
    final venueCtrl = TextEditingController(text: post.venue ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('✏️ Edit ${post.isEvent ? "Event" : "Post"} Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              if (post.isEvent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: venueCtrl,
                  decoration: const InputDecoration(labelText: 'Venue', border: OutlineInputBorder()),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC2410C), foregroundColor: Colors.white),
            onPressed: () {
              final updated = post.copyWith(
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                venue: post.isEvent ? venueCtrl.text.trim() : post.venue,
              );
              dataService.updatePost(updated);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Post updated successfully!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;

    // Requirement 6: All uploaded posts and events by current host
    final myPosts = dataService.posts.where((p) => p.authorId == user.id || p.authorName.contains(user.name)).toList();
    final myEvents = myPosts.where((p) => p.isEvent).toList();
    final myNotices = myPosts.where((p) => !p.isEvent).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Event Host Dashboard'),
        backgroundColor: const Color(0xFFC2410C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt),
            tooltip: 'Host New Event',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const CreateEventModal(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC2410C), Color(0xFFFB8C00)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Host Coordinator: ${user.name}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${myPosts.length} Total Uploaded Posts (${myEvents.length} Events, ${myNotices.length} Notices)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFC2410C),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const CreateEventModal(),
                        );
                      },
                      icon: const Icon(Icons.event, size: 16),
                      label: const Text('New Event'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const CreatePostModal(),
                        );
                      },
                      icon: const Icon(Icons.announcement, size: 16),
                      label: const Text('New Notice'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFC2410C),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFC2410C),
              tabs: [
                Tab(text: 'My Hosted Events (${myEvents.length})'),
                Tab(text: 'My Uploaded Notices (${myNotices.length})'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsList(context, dataService, myEvents, 'No events created yet. Tap New Event!'),
                _buildPostsList(context, dataService, myNotices, 'No notices published yet.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(BuildContext context, MockDataService dataService, List<PostModel> postsList, String emptyMsg) {
    if (postsList.isEmpty) {
      return Center(
        child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: postsList.length,
      itemBuilder: (ctx, idx) {
        final item = postsList[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.isEvent ? Colors.orange.shade100 : Colors.blue.shade100,
                  child: Icon(item.isEvent ? Icons.event : Icons.announcement, color: item.isEvent ? Colors.orange : Colors.blue),
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  item.isEvent
                      ? 'Venue: ${item.venue ?? "Campus"} • ${item.currentRegistrations}/${item.maxParticipants ?? "∞"} Registered'
                      : '${item.department} • ${item.category.displayName}',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 8),
              // Requirement 6: Edit & Delete Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                      label: const Text('Edit Post', style: TextStyle(color: Colors.blue)),
                      onPressed: () => _showEditDialog(context, dataService, item),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        dataService.deletePost(item.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🗑️ Post deleted successfully.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
