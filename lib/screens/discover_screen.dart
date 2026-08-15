import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/app_image.dart';
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
  String? selectedDept;
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

  int _engagementScore(PostModel p) =>
      p.likeCount + p.saveCount + p.congratulateCount;

  void _openDept(String dept) {
    searchController.clear();
    setState(() {
      selectedDept = dept;
      searchQuery = '';
    });
  }

  void _openSearch(String query) {
    setState(() {
      selectedDept = null;
      searchQuery = query;
      searchController.text = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<MockDataService>();
    final cfg = dataService.config;
    final savedIds = dataService.currentUser.savedPostIds;
    final registeredIds = dataService.currentUser.registeredEventIds;
    final congratulatedIds = dataService.currentUser.congratulatedPostIds;
    final likedIds = dataService.currentUser.likedPostIds;
    final filteredPosts = dataService.getPersonalizedFeed(
      searchQuery: searchQuery,
    );
    final nonEventPosts = dataService.posts
        .where((p) => !p.isEvent && dataService.matchesYear(p))
        .toList(growable: false);

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

    PostCard buildCard(PostModel post) => PostCard(
      post: post,
      config: cfg,
      isSaved: savedIds.contains(post.id),
      isRegistered: registeredIds.contains(post.id),
      isCongratulated: congratulatedIds.contains(post.id),
      isLiked: likedIds.contains(post.id),
      currentUserId: dataService.currentUser.id,
      onToggleSave: () => _handleToggleSave(dataService, post),
      onToggleRegister: () => _handleToggleRegister(dataService, post),
      onToggleCongratulate: () => _handleToggleCongratulate(dataService, post),
      onToggleLike: () => _handleToggleLike(dataService, post),
    );

    return PopScope(
      // Inside a department feed or search results the Android back button
      // steps back to Discover's main feed before it can close the app.
      canPop: selectedDept == null && searchQuery.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (selectedDept != null) {
            selectedDept = null;
          } else if (searchQuery.isNotEmpty) {
            searchQuery = '';
            searchController.clear();
          }
        });
      },
      child: Scaffold(
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
                return buildCard(filteredPosts[index]);
              },
            ),
          ] else if (selectedDept != null) ...[
            ..._buildDepartmentFeedSlivers(dataService, selectedDept, buildCard),
          ] else ...[
            ..._buildExploreSlivers(dataService, nonEventPosts, cfg, buildCard),
          ],
        ],
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Department feed view (a single department's posts)
  // ---------------------------------------------------------------------------
  List<Widget> _buildDepartmentFeedSlivers(
    MockDataService dataService,
    String? dept,
    PostCard Function(PostModel) buildCard,
  ) {
    final deptName = dept!;
    final stats = _deptStats(dataService, deptName);
    final deptPosts = dataService.posts
        .where((p) => p.department == deptName && !p.isEvent)
        .toList(growable: false);
    final accent = context
        .select((MockDataService s) => s.config)
        .colorForCategory(PostCategory.academic);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => selectedDept = null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_ios_new, size: 14, color: accent),
                  const SizedBox(width: 6),
                  const Text(
                    'All Departments',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.school_outlined, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deptName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stats.posts} posts • ${stats.faculty} faculty members',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (deptPosts.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No posts from this department yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: deptPosts.length,
          itemBuilder: (context, index) => buildCard(deptPosts[index]),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  // ---------------------------------------------------------------------------
  // Explore hub (default Discover body)
  // ---------------------------------------------------------------------------
  List<Widget> _buildExploreSlivers(
    MockDataService dataService,
    List<PostModel> nonEventPosts,
    AppConfig cfg,
    PostCard Function(PostModel) buildCard,
  ) {
    final accent = cfg.colorForCategory(PostCategory.academic);

    // Stats row
    final deptCount = nonEventPosts
        .map((p) => p.department)
        .where((d) => d.isNotEmpty)
        .toSet()
        .length;
    final facultyCount = nonEventPosts
        .where((p) => p.authorRole == UserRole.faculty)
        .map((p) => p.authorName)
        .toSet()
        .length;

    // Trending: top 3 by engagement (saves + congratulations)
    final trending = [...nonEventPosts]
      ..sort((a, b) => _engagementScore(b).compareTo(_engagementScore(a)));
    final trendingTop = trending.take(3).toList();

    // Departments ordered by post count
    final deptCounts = <String, int>{};
    for (final p in nonEventPosts) {
      if (p.department.isNotEmpty) {
        deptCounts[p.department] = (deptCounts[p.department] ?? 0) + 1;
      }
    }
    final topDepts = deptCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final featuredDepts = topDepts.take(3).toList();

    // People: real faculty & event hosts from the feed
    final people = <({String name, UserRole role, String dept, int postCount})>[];
    final seen = <String>{};
    for (final p in nonEventPosts) {
      if (p.authorRole == UserRole.student) continue;
      if (!seen.add(p.authorName)) continue;
      people.add((
        name: p.authorName,
        role: p.authorRole,
        dept: p.department,
        postCount: nonEventPosts.where((x) => x.authorName == p.authorName).length,
      ));
    }
    people.sort((a, b) {
      if (a.role != b.role) return a.role == UserRole.faculty ? -1 : 1;
      return b.postCount.compareTo(a.postCount);
    });
    final peopleTop = people.take(4).toList();

    return [
      // Stats hero chips
      if (nonEventPosts.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                _StatChip(icon: Icons.article_outlined, label: '${nonEventPosts.length} Posts'),
                const SizedBox(width: 8),
                _StatChip(icon: Icons.apartment_rounded, label: '$deptCount Departments'),
                const SizedBox(width: 8),
                _StatChip(icon: Icons.school_outlined, label: '$facultyCount Faculty'),
              ],
            ),
          ),
        ),

      // Departments directory
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
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
                onTap: () => _openDept(dept),
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

      // Trending at Campus — ranked by engagement
      if (trendingTop.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '🔥 Trending at Campus',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ...trendingTop.asMap().entries.map(
          (entry) => SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _TrendingBadge(
                    rank: entry.key + 1,
                    post: entry.value,
                  ),
                ),
                buildCard(entry.value),
              ],
            ),
          ),
        ),
      ],

      // Browse by Department — compact tiles
      if (featuredDepts.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '🗂️ Browse by Department',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        for (final deptEntry in featuredDepts) ...[
          SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      deptEntry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${deptEntry.value} posts',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _openDept(deptEntry.key),
                    child: Text(
                      'View all →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
          ...nonEventPosts
              .where((p) => p.department == deptEntry.key)
              .take(2)
              .map(
                (post) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: _DeptPostTile(
                      post: post,
                      onTap: () => _openDept(deptEntry.key),
                    ),
                  ),
                ),
              ),
        ],
      ],

      // People — real faculty & hosts from the feed
      if (peopleTop.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '👨‍🏫 People to Follow',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ...peopleTop.map(
          (person) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                leading: CircleAvatar(
                  backgroundColor: person.role == UserRole.faculty
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFFFEDD5),
                  child: Icon(
                    person.role == UserRole.faculty
                        ? Icons.school_rounded
                        : Icons.event_available_rounded,
                    color: person.role == UserRole.faculty
                        ? const Color(0xFF0369A1)
                        : const Color(0xFFC2410C),
                  ),
                ),
                title: Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${person.dept} • ${person.postCount} post${person.postCount == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoleBadge(role: person.role, isCompact: true),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ),
                onTap: () => _openSearch(person.name),
              ),
            ),
          ),
        ),
      ],

      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  void _handleToggleSave(MockDataService dataService, PostModel post) {
    dataService.toggleSavePost(post.id);
  }

  void _handleToggleLike(MockDataService dataService, PostModel post) {
    dataService.toggleLikePost(post.id);
  }

  void _handleToggleCongratulate(MockDataService dataService, PostModel post) {
    dataService.toggleCongratulate(post.id);
  }

  void _handleToggleRegister(MockDataService dataService, PostModel post) {
    dataService.toggleEventRegistration(post.id);
  }
}

/// Small stats chip shown in the hero row.
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rank badge shown above trending posts (#1 gold, #2 silver, #3 bronze).
class _TrendingBadge extends StatelessWidget {
  final int rank;
  final PostModel post;

  const _TrendingBadge({required this.rank, required this.post});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFF5A300),
      const Color(0xFF9AA3AC),
      const Color(0xFFB08D57),
    ];
    final color = colors[rank - 1];
    final likes = post.likeCount;
    final saves = post.saveCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '#$rank Trending',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.favorite_border, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 3),
          Text(
            '$likes',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Icon(Icons.bookmark_border, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 3),
          Text(
            '$saves saves',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// Compact single-post tile used in the "Browse by Department" sections, so
/// Discover looks different from Home's full-size post cards.
class _DeptPostTile extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const _DeptPostTile({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: post.imageUrl != null
                    ? AppImage(
                        source: post.imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.article_outlined,
                          size: 22,
                          color: Colors.grey,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${post.authorName} • ${formatEventDateTime(post.timestamp)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}