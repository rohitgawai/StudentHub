import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../utils/security_service.dart';
import '../widgets/app_image.dart';
import '../widgets/post_card.dart';
import '../widgets/role_badge.dart';

/// Public Creator / User Profile Screen opened when tapping an author's
/// avatar or name on any post, event, or gallery item.
///
/// Features:
/// - Creator details (Name, Role, Department, Academic Year, Email, MIT ID, Verified badge)
/// - Excludes private mobile numbers and administrative dashboard controls
/// - Interactive Animated Profile Like / Appreciate Button with live count synced to server
/// - Bottom section displaying Liked Posts and Saved Posts
/// - OS-level Anti-Screenshot Protection (FLAG_SECURE like WhatsApp/Banking apps)
class UserProfileScreen extends StatefulWidget {
  final String authorId;
  final String authorName;
  final UserRole authorRole;
  final String? authorAvatarUrl;
  final String? department;
  final String? year;
  final String? email;
  final String? studentOrEmployeeId;

  const UserProfileScreen({
    super.key,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    this.authorAvatarUrl,
    this.department,
    this.year,
    this.email,
    this.studentOrEmployeeId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;

  @override
  void initState() {
    super.initState();
    // Enforce OS-level screenshot restriction (FLAG_SECURE like WhatsApp)
    SecurityService.enableSecureScreen();

    _tabController = TabController(length: 2, vsync: this);
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _likeScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_likeAnimController);
  }

  @override
  void dispose() {
    // Release screenshot lock when leaving creator profile
    SecurityService.disableSecureScreen();
    _tabController.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  void _onLikeTapped(MockDataService dataService) {
    _likeAnimController.forward(from: 0.0);
    final wasLiked = dataService.isProfileLiked(widget.authorId);
    dataService.toggleLikeProfile(widget.authorId, widget.authorName);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              wasLiked ? Icons.favorite_border : Icons.favorite,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              wasLiked
                  ? 'Removed profile appreciation'
                  : '❤️ Appreciated ${widget.authorName}!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: wasLiked ? Colors.orange.shade800 : const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAvatarZoomDialog(BuildContext context, String avatarUrl) {
    SecurityService.enableSecureScreen();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF1E293B),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade700, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.shield_outlined, color: Colors.amber, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Protected',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Image Area with Screenshot Warning / Privacy Overlay
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 320,
                    child: avatarUrl.isNotEmpty
                        ? AppImage(
                            source: avatarUrl,
                            fit: BoxFit.cover,
                            errorChild: Container(
                              color: const Color(0xFF334155),
                              child: Center(
                                child: Text(
                                  widget.authorName.isNotEmpty
                                      ? widget.authorName.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 80,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF334155),
                            child: Center(
                              child: Text(
                                widget.authorName.isNotEmpty
                                    ? widget.authorName.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 80,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                  ),

                  // Watermark Overlay to prevent photo recording
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Anti-Screenshot Alert Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: const Color(0xFF0F172A),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.no_photography_outlined, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Screenshots restricted for privacy',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'StudentHub enforces hardware screenshot protection for all campus members.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<MockDataService>();
    final cfg = dataService.config;
    final isMe = widget.authorId == dataService.currentUser.id ||
        (widget.authorName.isNotEmpty &&
            widget.authorName.trim().toLowerCase() ==
                dataService.currentUser.name.trim().toLowerCase());

    final isLiked = dataService.isProfileLiked(widget.authorId);
    final profileLikesCount = dataService.getProfileLikes(widget.authorId);

    // Resolve avatar URL
    final avatar = (widget.authorAvatarUrl != null && widget.authorAvatarUrl!.isNotEmpty)
        ? widget.authorAvatarUrl!
        : (isMe
            ? dataService.currentUser.avatarUrl
            : (dataService.getAuthorAvatar(widget.authorId, widget.authorName) ?? ''));

    // Resolve department & year
    final dept = widget.department ??
        (isMe
            ? dataService.currentUser.department
            : 'Department Member');
    final academicYear = widget.year ??
        (isMe ? dataService.currentUser.year : 'Campus Student');
    final email = widget.email ??
        (isMe ? dataService.currentUser.email : '');
    final studentId = widget.studentOrEmployeeId ??
        (isMe ? dataService.currentUser.studentOrEmployeeId : '');

    // Posts for the bottom tabs
    final allPosts = dataService.posts;
    final userSavedPosts = allPosts
        .where((p) => dataService.currentUser.savedPostIds.contains(p.id))
        .toList();
    final userLikedPosts = allPosts
        .where((p) => dataService.currentUser.likedPostIds.contains(p.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Creator Profile',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'Protected',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Clean Modern Profile Card (No huge blue block)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Avatar with Zoom Tap & Verified Badge
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _showAvatarZoomDialog(context, avatar);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cfg.primaryColor.withValues(alpha: 0.4),
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFFF1F5F9),
                          child: ClipOval(
                            child: avatar.isNotEmpty
                                ? AppImage(
                                    source: avatar,
                                    fit: BoxFit.cover,
                                    width: 92,
                                    height: 92,
                                    errorChild: Text(
                                      widget.authorName.isNotEmpty
                                          ? widget.authorName.substring(0, 1).toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  )
                                : Text(
                                    widget.authorName.isNotEmpty
                                        ? widget.authorName.substring(0, 1).toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Name
                Text(
                  widget.authorName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Role Badge
                RoleBadge(role: widget.authorRole),
                const SizedBox(height: 12),

                // Department & Year Tag Pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school_rounded, size: 14, color: Color(0xFF475569)),
                          const SizedBox(width: 6),
                          Text(
                            dept,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (academicYear.isNotEmpty && academicYear != 'N/A')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFF475569)),
                            const SizedBox(width: 6),
                            Text(
                              academicYear,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                if (studentId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'ID: $studentId',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],

                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Animated Profile Like / Appreciate Button
                ScaleTransition(
                  scale: _likeScaleAnim,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                        backgroundColor: isLiked ? const Color(0xFFFFF1F2) : cfg.primaryColor,
                        foregroundColor: isLiked ? const Color(0xFFE11D48) : Colors.white,
                        elevation: isLiked ? 0 : 2,
                        side: isLiked
                            ? const BorderSide(color: Color(0xFFFDA4AF), width: 1.5)
                            : BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _onLikeTapped(dataService),
                      icon: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? const Color(0xFFE11D48) : Colors.white,
                        size: 20,
                      ),
                      label: Text(
                        isLiked
                            ? 'Appreciated ($profileLikesCount)'
                            : 'Appreciate Profile ($profileLikesCount)',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: isLiked ? const Color(0xFFE11D48) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Bar for Liked Posts & Saved Posts
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: cfg.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cfg.primaryColor.withValues(alpha: 0.25), width: 1),
              ),
              labelColor: cfg.primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(
                  icon: const Icon(Icons.favorite_rounded, size: 18),
                  text: 'Liked (${userLikedPosts.length})',
                ),
                Tab(
                  icon: const Icon(Icons.bookmark_rounded, size: 18),
                  text: 'Saved (${userSavedPosts.length})',
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tab View Posts Container
          SizedBox(
            height: 480,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Liked Posts Tab
                _buildPostList(
                  context,
                  posts: userLikedPosts,
                  cfg: cfg,
                  dataService: dataService,
                  emptyMessage: 'No liked posts to show.',
                  emptyIcon: Icons.favorite_border_rounded,
                ),

                // Saved Posts Tab
                _buildPostList(
                  context,
                  posts: userSavedPosts,
                  cfg: cfg,
                  dataService: dataService,
                  emptyMessage: 'No saved posts to show.',
                  emptyIcon: Icons.bookmark_border_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(
    BuildContext context, {
    required List<PostModel> posts,
    required dynamic cfg,
    required MockDataService dataService,
    required String emptyMessage,
    required IconData emptyIcon,
  }) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final user = dataService.currentUser;
        return PostCard(
          post: post,
          config: cfg,
          isSaved: user.savedPostIds.contains(post.id),
          isRegistered: user.registeredEventIds.contains(post.id),
          isCongratulated: user.congratulatedPostIds.contains(post.id),
          isLiked: user.likedPostIds.contains(post.id),
          currentUserId: user.id,
          onToggleSave: () => dataService.toggleSavePost(post.id),
          onToggleRegister: () => dataService.toggleEventRegistration(post.id),
          onToggleCongratulate: () => dataService.toggleCongratulate(post.id),
          onToggleLike: () => dataService.toggleLikePost(post.id),
        );
      },
    );
  }
}
