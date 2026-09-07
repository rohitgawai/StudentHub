import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import 'post_detail_screen.dart';

class _ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<PostModel> citations;

  _ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.citations = const [],
  });
}

/// Dedicated StudentHub AI campus assistant interface.
/// Seamlessly answers campus queries, summarizes notices, lists scholarships,
/// and presents interactive citation cards that open standalone post pages.
class StudentHubAiScreen extends StatefulWidget {
  const StudentHubAiScreen({super.key});

  @override
  State<StudentHubAiScreen> createState() => _StudentHubAiScreenState();
}

class _StudentHubAiScreenState extends State<StudentHubAiScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  static const List<Map<String, dynamic>> _quickPrompts = [
    {
      'label': 'Scholarship updates',
      'icon': Icons.school_outlined,
      'query': 'Tell me about scholarship updates and financial grants available for students.',
    },
    {
      'label': 'Upcoming hackathons',
      'icon': Icons.emoji_events_outlined,
      'query': 'What upcoming hackathons and coding competitions are happening this month?',
    },
    {
      'label': 'Summarize exam notices',
      'icon': Icons.assignment_outlined,
      'query': 'Summarize the latest urgent academic exam notices and schedule revisions.',
    },
    {
      'label': 'Fee submission dates',
      'icon': Icons.calendar_month_outlined,
      'query': 'When is the deadline for college fees submission and registration?',
    },
    {
      'label': 'Campus events & workshops',
      'icon': Icons.celebration_outlined,
      'query': 'Show me fun workshops, tech talks, and cultural events happening on campus.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initWelcomeMessage();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initWelcomeMessage() {
    _messages.clear();
    _messages.add(
      _ChatMessage(
        id: 'msg_init',
        text: 'Hello! 👋 I am **StudentHub AI**, your campus assistant.\n\nAsk me anything about college notices, scholarship updates, upcoming hackathons, exam schedules, or fee deadlines!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleSubmitted(String text) {
    final query = text.trim();
    if (query.isEmpty) return;

    _textController.clear();
    final userMsg = _ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    // Process query with campus database
    _generateAiResponse(query);
  }

  void _generateAiResponse(String query) {
    final dataService = context.read<MockDataService>();
    final allPosts = dataService.posts;
    final lower = query.toLowerCase();

    Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;

      String replyText = '';
      List<PostModel> matchedPosts = [];

      if (lower.contains('scholarship') || lower.contains('grant') || lower.contains('fee')) {
        matchedPosts = allPosts.where((p) {
          final t = '${p.title} ${p.description}'.toLowerCase();
          return t.contains('scholarship') || t.contains('grant') || t.contains('fee') || t.contains('award');
        }).toList();

        if (matchedPosts.isNotEmpty) {
          replyText = '🎓 **Scholarship & Financial Updates**:\n\n'
              'Here are the active scholarship announcements and financial notifications found for your campus:';
        } else {
          replyText = '🎓 **Scholarship Updates**:\n\n'
              'Currently, college scholarship renewal and national fellowship forms are active. Please check the administrative office for EBC, minority scholarships, and corporate sponsor grants. You can also view the notifications tab for real-time announcements.';
        }
      } else if (lower.contains('hackathon') || lower.contains('contest') || lower.contains('coding')) {
        matchedPosts = allPosts.where((p) {
          final t = '${p.title} ${p.description}'.toLowerCase();
          return t.contains('hackathon') || t.contains('flutter') || t.contains('coding') || t.contains('contest') || p.isEvent;
        }).take(3).toList();

        replyText = '🏆 **Upcoming Hackathons & Contests**:\n\n'
            'We found relevant tech hackathons and innovation challenges listed on campus! Check the event dates and register before the slots fill up:';
      } else if (lower.contains('exam') || lower.contains('schedule') || lower.contains('mid-sem') || lower.contains('notice')) {
        matchedPosts = allPosts.where((p) {
          return p.category == PostCategory.announcement || p.category == PostCategory.academic;
        }).take(3).toList();

        replyText = '📢 **Campus Notice & Exam Summary**:\n\n'
            'The examination section has posted important circulars regarding schedules, seating plans, and attendance criteria:';
      } else {
        // Semantic keyword search over campus posts
        final tokens = lower.split(' ').where((t) => t.length > 2).toList();
        matchedPosts = allPosts.where((p) {
          final t = '${p.title} ${p.description} ${p.department}'.toLowerCase();
          return tokens.any((tok) => t.contains(tok));
        }).take(3).toList();

        if (matchedPosts.isNotEmpty) {
          replyText = 'Here is what I found in the campus records regarding your query:';
        } else {
          replyText = 'I analyzed the latest college bulletins and departmental notices for **"$query"**.\n\n'
              'For further assistance, explore the Discover tab or search directly using the top search bar!';
        }
      }

      final aiMsg = _ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        text: replyText,
        isUser: false,
        timestamp: DateTime.now(),
        citations: matchedPosts,
      );

      setState(() {
        _isTyping = false;
        _messages.add(aiMsg);
      });
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = context.select((MockDataService s) => s.config.primaryColor);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'StudentHub AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Campus Intelligent Assistant',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New Chat',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _initWelcomeMessage();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat message stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageItem(msg, isDark, primaryColor);
                },
              ),
            ),

            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F1F24) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2B2B33) : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'StudentHub AI is finding info...',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Quick suggestion chips
            if (_messages.length <= 2)
              Container(
                height: 42,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final p = _quickPrompts[i];
                    return ActionChip(
                      avatar: Icon(p['icon'] as IconData, size: 14, color: primaryColor),
                      label: Text(p['label'] as String),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      backgroundColor: isDark ? const Color(0xFF1A1A20) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF2D2D35) : Colors.grey.shade300,
                        ),
                      ),
                      onPressed: () => _handleSubmitted(p['query'] as String),
                    );
                  },
                ),
              ),

            // Bottom prompt input field
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141418) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F1F24) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _handleSubmitted,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask StudentHub AI anything about campus...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      onPressed: () => _handleSubmitted(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage msg, bool isDark, Color primaryColor) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    // AI message with citations
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A20) : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: isDark ? const Color(0xFF272730) : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF1E293B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (msg.citations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tappable Campus Resources:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...msg.citations.map((post) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // Opens individual post page as requested
                          PostDetailScreen.navigateTo(context, post.id);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF202028) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E2E38) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                post.isEvent ? Icons.event : Icons.article_outlined,
                                size: 18,
                                color: post.isEvent ? Colors.purple : primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  post.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
