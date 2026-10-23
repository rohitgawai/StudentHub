import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/role_badge.dart';
import '../widgets/app_image.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

/// Instagram / X (Twitter) style full-page dedicated search screen.
/// Opens with a blank/clean backdrop, auto-focused search bar, recent search history,
/// trending campus tags, and instant keyword/semantic results.
class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  static Future<void> open(BuildContext context, {String initialQuery = ''}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SearchScreen(initialQuery: initialQuery),
      ),
    );
  }

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  List<String> _recentSearches = [];
  String _selectedFilter = 'All';

  static const List<String> _trendingTopics = [
    'Hackathons',
    'Scholarships',
    'Mid-Sem Exams',
    'Placements',
    'AI & ML',
    'Internships',
    'Cultural Fest',
    'Syllabus',
  ];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _controller = TextEditingController(text: widget.initialQuery);
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery.isEmpty) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('sh_recent_searches') ?? [];
      if (mounted) {
        setState(() {
          _recentSearches = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = [trimmed, ..._recentSearches.where((q) => q.toLowerCase() != trimmed.toLowerCase())];
      if (updated.length > 10) {
        updated.removeRange(10, updated.length);
      }
      await prefs.setStringList('sh_recent_searches', updated);
      if (mounted) {
        setState(() {
          _recentSearches = updated;
        });
      }
    } catch (_) {}
  }

  Future<void> _removeRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = _recentSearches.where((q) => q != query).toList();
      await prefs.setStringList('sh_recent_searches', updated);
      if (mounted) {
        setState(() {
          _recentSearches = updated;
        });
      }
    } catch (_) {}
  }

  Future<void> _clearAllRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sh_recent_searches');
      if (mounted) {
        setState(() {
          _recentSearches = [];
        });
      }
    } catch (_) {}
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isNotEmpty) {
      _saveSearchQuery(query);
    }
  }

  List<PostModel> _filterPosts(List<PostModel> allPosts) {
    if (_query.trim().isEmpty) return [];

    final tokens = _query.toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();

    var results = allPosts.where((post) {
      final textToMatch = '${post.title} ${post.description} ${post.department} ${post.authorName} ${post.category.displayName}'.toLowerCase();

      // Check for matching keywords
      return tokens.every((token) => textToMatch.contains(token));
    }).toList();

    if (_selectedFilter == 'Events') {
      results = results.where((p) => p.isEvent).toList();
    } else if (_selectedFilter == 'Notices') {
      results = results.where((p) => p.category == PostCategory.announcement).toList();
    } else if (_selectedFilter == 'Scholarships') {
      results = results.where((p) {
        final text = '${p.title} ${p.description}'.toLowerCase();
        return text.contains('scholarship') || text.contains('grant') || text.contains('fellowship');
      }).toList();
    } else if (_selectedFilter == 'Academic') {
      results = results.where((p) => p.category == PostCategory.academic).toList();
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<MockDataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = dataService.config.primaryColor;
    final matchingPosts = _filterPosts(dataService.posts);
    final matchingUsers = dataService.searchUsers(_query);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF141418) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1F24) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: _onSearchSubmitted,
            onChanged: (val) {
              setState(() {
                _query = val;
              });
            },
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Search posts, events, scholarships...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, size: 18),
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      body: _query.trim().isEmpty
          ? _buildBlankState(isDark, primaryColor)
          : _buildSearchResults(context, isDark, primaryColor, matchingPosts, matchingUsers, dataService),
    );
  }

  /// Blank/Clean state (Instagram/Twitter style) showing recent searches and trending tags
  Widget _buildBlankState(bool isDark, Color primaryColor) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: _clearAllRecentSearches,
                child: Text(
                  'Clear all',
                  style: TextStyle(fontSize: 12, color: primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._recentSearches.map((item) {
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(
                Icons.history,
                size: 18,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              title: Text(
                item,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                onPressed: () => _removeRecentSearch(item),
              ),
              onTap: () {
                _controller.text = item;
                setState(() {
                  _query = item;
                });
                _onSearchSubmitted(item);
              },
            );
          }),
          const SizedBox(height: 16),
          Divider(color: isDark ? const Color(0xFF262626) : Colors.grey.shade200),
          const SizedBox(height: 12),
        ],
        Text(
          'Explore Campus Topics',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trendingTopics.map((topic) {
            return ActionChip(
              avatar: const Icon(Icons.tag, size: 14),
              label: Text(topic),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              backgroundColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? const Color(0xFF2D2D35) : const Color(0xFFE2E8F0),
                ),
              ),
              onPressed: () {
                _controller.text = topic;
                setState(() {
                  _query = topic;
                });
                _onSearchSubmitted(topic);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUserAccountTile(
    BuildContext context,
    UserModel user,
    bool isDark,
    Color primaryColor,
    MockDataService dataService,
  ) {
    final avatar = dataService.getAuthorAvatar(user.id, user.name) ?? user.avatarUrl;
    final role = user.roles.isNotEmpty ? user.roles.first : UserRole.student;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        _onSearchSubmitted(_query);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => UserProfileScreen(
              authorId: user.id,
              authorName: user.name,
              authorRole: role,
              authorAvatarUrl: avatar,
              department: user.department,
              year: user.year,
              email: user.email,
              studentOrEmployeeId: user.studentOrEmployeeId,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              child: ClipOval(
                child: avatar.isNotEmpty
                    ? AppImage(
                        source: avatar,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorChild: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      )
                    : Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      RoleBadge(role: role),
                      if (user.department.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            user.department,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  /// Results view with filter pills and individual post navigation
  Widget _buildSearchResults(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    List<PostModel> posts,
    List<UserModel> users,
    MockDataService dataService,
  ) {
    const filters = ['All', 'Accounts', 'Events', 'Notices', 'Scholarships', 'Academic'];

    final showAccountsOnly = _selectedFilter == 'Accounts';
    final hasNoResults = showAccountsOnly
        ? users.isEmpty
        : (_selectedFilter == 'All' ? (users.isEmpty && posts.isEmpty) : posts.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(filter == 'Accounts' && users.isNotEmpty ? 'Accounts (${users.length})' : filter),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
                  ),
                  selectedColor: primaryColor,
                  backgroundColor: isDark ? const Color(0xFF1F1F24) : const Color(0xFFF1F5F9),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? const Color(0xFF2E2E38) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Divider(
          height: 1,
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
        ),
        // Results list
        Expanded(
          child: hasNoResults
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          showAccountsOnly
                              ? 'No accounts matching "$_query"'
                              : 'No campus results for "$_query"',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          showAccountsOnly
                              ? 'Try searching by student/faculty name, department, or student ID.'
                              : 'Try searching for creators, hackathons, notices, or scholarships.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : showAccountsOnly
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: users.length,
                      separatorBuilder: (ctx, i) => Divider(
                        height: 12,
                        color: isDark ? const Color(0xFF202025) : Colors.grey.shade100,
                      ),
                      itemBuilder: (context, index) {
                        return _buildUserAccountTile(
                          context,
                          users[index],
                          isDark,
                          primaryColor,
                          dataService,
                        );
                      },
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        // If in 'All' view and matching users exist, show prominent Social Media People section at top
                        if (users.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'People & Accounts (${users.length})',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              if (users.length > 3)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = 'Accounts';
                                    });
                                  },
                                  child: Text(
                                    'See all',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...users.take(3).map(
                                (u) => _buildUserAccountTile(
                                  context,
                                  u,
                                  isDark,
                                  primaryColor,
                                  dataService,
                                ),
                              ),
                          const SizedBox(height: 10),
                          Divider(
                            height: 16,
                            color: isDark ? const Color(0xFF202025) : Colors.grey.shade200,
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (posts.isNotEmpty) ...[
                          if (users.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Posts & Events (${posts.length})',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ...List.generate(posts.length, (index) {
                            final post = posts[index];
                            return Column(
                              children: [
                                if (index > 0)
                                  Divider(
                                    height: 16,
                                    color: isDark ? const Color(0xFF202025) : Colors.grey.shade100,
                                  ),
                                InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _onSearchSubmitted(_query);
                        PostDetailScreen.navigateTo(context, post.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: post.isEvent
                                    ? Colors.purple.withValues(alpha: 0.15)
                                    : primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                post.isEvent
                                    ? Icons.event
                                    : post.category == PostCategory.announcement
                                        ? Icons.campaign
                                        : Icons.article_outlined,
                                color: post.isEvent ? Colors.purple : primaryColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF24242A)
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          post.isEvent
                                              ? 'EVENT'
                                              : post.category.displayName.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          post.department,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    post.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    post.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}
