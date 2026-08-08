import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';
import '../widgets/role_badge.dart';
import '../models/user_model.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String searchQuery = '';
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  ({int posts, int faculty}) _deptStats(
    MockDataService dataService,
    String dept,
  ) {
    final deptPosts = dataService.posts.where((p) => p.department == dept);
    final postCount = deptPosts.length;
    final faculty = deptPosts
        .where((p) => p.authorRole == UserRole.faculty)
        .map((p) => p.authorName)
        .toSet()
        .length;
    return (posts: postCount, faculty: faculty);
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<MockDataService>();
    final cfg = context.select((MockDataService s) => s.config);
    final userYear = context.select((MockDataService s) => s.currentUser.year);
    final savedIds = context.select(
      (MockDataService s) => s.currentUser.savedPostIds,
    );
    final registeredIds = context.select(
      (MockDataService s) => s.currentUser.registeredEventIds,
    );
    final congratulatedIds = context.select(
      (MockDataService s) => s.currentUser.congratulatedPostIds,
    );
    final filteredPosts = dataService.getPersonalizedFeed(
      searchQuery: searchQuery,
    );

    Widget searchField = TextField(
      controller: searchController,
      onChanged: (val) => setState(() => searchQuery = val),
      decoration: InputDecoration(
        hintText: '🔍 Search posts, events, faculty...',
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: searchField,
            ),
          ),
          if (searchQuery.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Search Results (${filteredPosts.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverList.builder(
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                final post = filteredPosts[index];
                return PostCard(
                  post: post,
                  config: cfg,
                  isSaved: savedIds.contains(post.id),
                  isRegistered: registeredIds.contains(post.id),
                  isCongratulated: congratulatedIds.contains(post.id),
                  userYear: userYear,
                  currentUserId: dataService.currentUser.id,
                  onToggleSave: () => _handleToggleSave(dataService, post),
                  onToggleRegister: () =>
                      _handleToggleRegister(dataService, post),
                  onToggleCongratulate: () =>
                      _handleToggleCongratulate(dataService, post),
                );
              },
            ),
          ] else ...[
            // Departments Directory Section — informative cards
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '🏫 Academic Departments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.45,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: cfg.departments.length,
                itemBuilder: (context, index) {
                  final dept = cfg.departments[index];
                  final stats = _deptStats(dataService, dept);
                  final accent = cfg.colorForCategory(PostCategory.academic);
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.school_outlined,
                                    size: 18,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dept,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.article_outlined,
                                  size: 13,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${stats.posts} Posts',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.badge_outlined,
                                  size: 13,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${stats.faculty} Faculty',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: accent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '👩‍🏫 Key Faculty & Event Hosts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    side: BorderSide(color: Colors.black12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.school, color: Color(0xFF0369A1)),
                  ),
                  title: Text('Dr. Ramesh K. Verma'),
                  subtitle: Text('Dean Academics • Computer Science'),
                  trailing: RoleBadge(role: UserRole.faculty, isCompact: true),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    side: BorderSide(color: Colors.black12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFFFEDD5),
                    child: Icon(Icons.event, color: Color(0xFFC2410C)),
                  ),
                  title: Text('Dev Society'),
                  subtitle: Text('Official Tech Club • Student Host'),
                  trailing: RoleBadge(
                    role: UserRole.eventHost,
                    isCompact: true,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '🔥 Popular Campus Announcements',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverList.builder(
              itemCount: 3,
              itemBuilder: (context, index) {
                final post = dataService.posts[index];
                return PostCard(
                  post: post,
                  config: cfg,
                  isSaved: savedIds.contains(post.id),
                  isRegistered: registeredIds.contains(post.id),
                  isCongratulated: congratulatedIds.contains(post.id),
                  userYear: userYear,
                  currentUserId: dataService.currentUser.id,
                  onToggleSave: () => _handleToggleSave(dataService, post),
                  onToggleRegister: () =>
                      _handleToggleRegister(dataService, post),
                  onToggleCongratulate: () =>
                      _handleToggleCongratulate(dataService, post),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _handleToggleSave(MockDataService dataService, PostModel post) {
    dataService.toggleSavePost(post.id);
    final isSaved = dataService.currentUser.savedPostIds.contains(post.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSaved ? 'Saved to Profile!' : 'Removed from saved posts',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleToggleCongratulate(MockDataService dataService, PostModel post) {
    dataService.toggleCongratulate(post.id);
    final isCongratulated =
        dataService.currentUser.congratulatedPostIds.contains(post.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCongratulated
              ? '👏 Congratulated ${post.authorName}!'
              : 'Removed congratulations',
        ),
        backgroundColor: isCongratulated
            ? const Color(0xFF8E24AA)
            : Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleToggleRegister(MockDataService dataService, PostModel post) {
    final wasRegistered = dataService.currentUser.registeredEventIds.contains(
      post.id,
    );
    dataService.toggleEventRegistration(post.id);
    final isRegistered = dataService.currentUser.registeredEventIds.contains(
      post.id,
    );
    if (wasRegistered == isRegistered) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isRegistered
              ? '🎉 Successfully registered for ${post.title}!'
              : 'Unregistered from event.',
        ),
        backgroundColor: isRegistered ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}