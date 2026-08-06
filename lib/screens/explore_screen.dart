import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';
import '../widgets/role_badge.dart';
import '../models/user_model.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String searchQuery = '';
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final cfg = dataService.config;
    final filteredPosts = dataService.getPersonalizedFeed(searchQuery: searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Explore Campus'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search Input
          TextField(
            controller: searchController,
            onChanged: (val) => setState(() => searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search announcements, departments, faculty...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        setState(() => searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
            ),
          ),
          const SizedBox(height: 20),

          if (searchQuery.isNotEmpty) ...[
            Text(
              'Search Results (${filteredPosts.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...filteredPosts.map((p) => PostCard(post: p)),
          ] else ...[
            // Departments Directory Section
            const Text(
              '🏫 Academic Departments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: cfg.departments.length,
              itemBuilder: (context, index) {
                final dept = cfg.departments[index];
                return Card(
                  elevation: 0,
                  color: cfg.primaryColor.withOpacity(0.08),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      searchController.text = dept;
                      setState(() => searchQuery = dept);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dept,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cfg.primaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          const Text('View Updates ›', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            // Featured Faculty & Hosts Directory
            const Text(
              '👩‍🏫 Key Faculty & Event Hosts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black12),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0F2FE),
                child: Icon(Icons.school, color: Color(0xFF0369A1)),
              ),
              title: const Text('Dr. Ramesh K. Verma'),
              subtitle: const Text('Dean Academics • Computer Science'),
              trailing: const RoleBadge(role: UserRole.faculty, isCompact: true),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black12),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEDD5),
                child: Icon(Icons.event, color: Color(0xFFC2410C)),
              ),
              title: const Text('Dev Society'),
              subtitle: const Text('Official Tech Club • Student Host'),
              trailing: const RoleBadge(role: UserRole.eventHost, isCompact: true),
            ),

            const SizedBox(height: 24),
            // Popular Campus Announcements
            const Text(
              '🔥 Popular Campus Announcements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...dataService.posts.take(3).map((p) => PostCard(post: p)),
          ],
        ],
      ),
    );
  }
}
