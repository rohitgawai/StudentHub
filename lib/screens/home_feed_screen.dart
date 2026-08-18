import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';
import '../widgets/app_toast.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  String searchQuery = '';
  final searchController = TextEditingController();
  final scrollController = ScrollController();

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleRefresh(MockDataService dataService) async {
    final success = await dataService.refreshFeed();
    if (mounted) {
      if (success) {
        AppToast.showSuccess(context, 'Campus feed refreshed');
      } else {
        AppToast.showWarning(context, 'No internet · Showing cached feed');
      }
    }
  }

  void _handleToggleSave(MockDataService dataService, PostModel post) {
    dataService.toggleSavePost(post.id);
  }

  void _handleToggleCongratulate(MockDataService dataService, PostModel post) {
    dataService.toggleCongratulate(post.id);
  }

  void _handleToggleLike(MockDataService dataService, PostModel post) {
    dataService.toggleLikePost(post.id);
  }

  void _handleToggleRegister(MockDataService dataService, PostModel post) {
    dataService.toggleEventRegistration(post.id);
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<MockDataService>();
    final cfg = dataService.config;
    final isLoading = dataService.isLoading;
    final savedIds = dataService.currentUser.savedPostIds;
    final registeredIds = dataService.currentUser.registeredEventIds;
    final congratulatedIds = dataService.currentUser.congratulatedPostIds;
    final likedIds = dataService.currentUser.likedPostIds;

    final posts = dataService.getPersonalizedFeed(
      categoryFilter: null,
      searchQuery: searchQuery,
      excludeEvents: true,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search posts, events, faculty...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          searchController.clear();
                          setState(() => searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cfg.primaryColor),
                ),
              ),
            ),
          ),

          // Pull-to-refresh feed; skeleton placeholders while initial data loads
          Expanded(
            child: RefreshIndicator(
              color: cfg.primaryColor,
              onRefresh: () => _handleRefresh(dataService),
              child: isLoading
                  ? const FeedSkeleton()
                  : posts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.feed_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No posts for your year yet.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return PostCard(
                          key: ValueKey(post.id),
                          post: post,
                          config: cfg,
                          isSaved: savedIds.contains(post.id),
                          isRegistered: registeredIds.contains(post.id),
                          isCongratulated: congratulatedIds.contains(post.id),
                          isLiked: likedIds.contains(post.id),
                          currentUserId: dataService.currentUser.id,
                          onToggleSave: () =>
                              _handleToggleSave(dataService, post),
                          onToggleRegister: () =>
                              _handleToggleRegister(dataService, post),
                          onToggleCongratulate: () =>
                              _handleToggleCongratulate(dataService, post),
                          onToggleLike: () => _handleToggleLike(dataService, post),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}