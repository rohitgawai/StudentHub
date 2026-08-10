import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../utils/date_formatter.dart';
import 'registrants_screen.dart';

/// Entry screen for host/faculty: every event/workshop/post of theirs that
/// has registrations or form responses, with counts. Tap to open the
/// registrant list. One row per post keeps the dashboard clean.
class RegistrationStatsScreen extends StatefulWidget {
  const RegistrationStatsScreen({super.key});

  @override
  State<RegistrationStatsScreen> createState() =>
      _RegistrationStatsScreenState();
}

class _RegistrationStatsScreenState extends State<RegistrationStatsScreen> {
  static const Color _accent = Color(0xFF1565C0);

  List<PostModel> _buildRows(MockDataService service) {
    final myId = service.currentUser.id;
    return service.posts
        .where(
          (p) =>
              p.authorId == myId &&
              (p.form != null ||
                  p.registeredUserIds.isNotEmpty ||
                  service.submissionsForPost(p.id).isNotEmpty),
        )
        .toList();
  }

  int _countFor(MockDataService service, PostModel post) {
    if (post.isEvent) return post.registeredUserIds.length;
    return service.submissionsForPost(post.id).length;
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<MockDataService>(context);
    final rows = _buildRows(service);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Registration Stats'),
        centerTitle: false,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: rows.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.query_stats,
                    size: 54,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No registrations yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'When students register for your events or fill your\nforms, they appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${rows.length} ${rows.length == 1 ? 'post' : 'posts'} with '
                          '${rows.fold<int>(0, (sum, p) => sum + _countFor(service, p))} '
                          'total registrations',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: rows.length,
                    itemBuilder: (ctx, idx) {
                      final post = rows[idx];
                      final count = _countFor(service, post);
                      final isEvent = post.isEvent;
                      return _StatCard(
                        post: post,
                        count: count,
                        subtitle: isEvent
                            ? (post.eventDate != null
                                  ? formatEventDateTime(post.eventDate!)
                                  : post.venue ?? 'Campus')
                            : (post.description.isEmpty
                                  ? post.category.displayName
                                  : post.description),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RegistrantsScreen(post: post),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final PostModel post;
  final int count;
  final String subtitle;
  final VoidCallback onTap;

  const _StatCard({
    required this.post,
    required this.count,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEvent = post.isEvent;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: (isEvent ? Colors.orange : Colors.blue)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEvent ? Icons.event_available : Icons.description_outlined,
                  color: isEvent ? Colors.orange.shade800 : Colors.blue.shade700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                    if (isEvent) ...[
                      const SizedBox(height: 4),
                      Text(
                        post.maxParticipants != null
                            ? 'Capacity ${post.currentRegistrations}/${post.maxParticipants}'
                            : 'Open capacity',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: (isEvent ? Colors.orange : Colors.blue)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isEvent ? Colors.orange.shade800 : Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}