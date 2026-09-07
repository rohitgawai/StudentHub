import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/ai_service.dart';
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
/// Accesses campus notices, events, workshops, attached PDFs, images, and coordinator profiles.
class StudentHubAiScreen extends StatefulWidget {
  const StudentHubAiScreen({super.key});

  @override
  State<StudentHubAiScreen> createState() => _StudentHubAiScreenState();
}

class _StudentHubAiScreenState extends State<StudentHubAiScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  http.Client? _activeClient;
  bool _wasCancelled = false;

  static const List<Map<String, dynamic>> _quickPrompts = [
    {
      'label': 'Scholarship updates',
      'icon': Icons.school_outlined,
      'query': 'Tell me about all scholarship updates, eligibility, and deadlines available on campus.',
    },
    {
      'label': 'Upcoming hackathons',
      'icon': Icons.emoji_events_outlined,
      'query': 'What upcoming hackathons, tech contests, or coding events are scheduled this month?',
    },
    {
      'label': 'Event coordinators',
      'icon': Icons.person_search_outlined,
      'query': 'Who are the event coordinators and faculty hosts for current events and workshops?',
    },
    {
      'label': 'Exam passing tips',
      'icon': Icons.lightbulb_outline_rounded,
      'query': 'Is there any tip to get pass in mid-sem and semester exams?',
    },
    {
      'label': 'Summarize notices & PDFs',
      'icon': Icons.assignment_outlined,
      'query': 'Summarize the latest urgent academic notices and attached document circulars.',
    },
    {
      'label': 'Fee submission dates',
      'icon': Icons.calendar_month_outlined,
      'query': 'When is the deadline for college semester fees submission?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initWelcomeMessage();
  }

  @override
  void dispose() {
    _activeClient?.close();
    _pulseController.dispose();
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
        text: 'Hello! 👋 I am **StudentHub AI**, your official campus assistant.\n\n'
            'I have live access to college notices, upcoming events, workshops, attached PDFs, and coordinator profiles.\n\n'
            'Ask me anything about academics, exam tips, scholarships, or campus activities!',
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
    if (_isTyping) {
      _stopAiGeneration();
      return;
    }

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

    _generateAiResponse(query);
  }

  void _stopAiGeneration() {
    if (!_isTyping) return;
    _wasCancelled = true;
    _activeClient?.close();
    _activeClient = null;
    _pulseController.stop();

    setState(() {
      _isTyping = false;
      _messages.add(
        _ChatMessage(
          id: 'msg_stopped_${DateTime.now().millisecondsSinceEpoch}',
          text: '⏹️ *Response stopped by user.*',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _generateAiResponse(String query) async {
    final dataService = context.read<MockDataService>();
    final allPosts = dataService.posts;

    // Convert past history for context
    final history = _messages
        .where((m) => m.id != 'msg_init' && !m.id.startsWith('msg_stopped_'))
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    _wasCancelled = false;
    _activeClient?.close();
    final currentClient = http.Client();
    _activeClient = currentClient;
    _pulseController.repeat(reverse: true);

    try {
      final aiResponse = await AiService.instance.ask(
        query: query,
        posts: allPosts,
        history: history,
        client: currentClient,
      );

      if (!mounted || _wasCancelled) return;

      final matchedPosts = allPosts
          .where((p) => aiResponse.citedPostIds.contains(p.id))
          .toList();

      final aiMsg = _ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        text: aiResponse.text,
        isUser: false,
        timestamp: DateTime.now(),
        citations: matchedPosts,
      );

      setState(() {
        _isTyping = false;
        _messages.add(aiMsg);
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted || _wasCancelled) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          _ChatMessage(
            id: 'msg_err_${DateTime.now().millisecondsSinceEpoch}',
            text:
                "I couldn't process your request right now. Please check your network connection and try again.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    } finally {
      if (mounted && !_isTyping) {
        _pulseController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = context.select((MockDataService s) => s.config.primaryColor);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Ultra-modern custom full-bleed AI Header
            _buildCustomAiHeader(isDark),

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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F1F24) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2B2B33) : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'StudentHub AI is analyzing campus data...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
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
                          hintText: 'Ask about notices, events, pass tips, PDFs...',
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
                  if (_isTyping)
                    GestureDetector(
                      onTap: _stopAiGeneration,
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.stop_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
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

  /// Custom top header extending to the status bar, replacing the standard app bar
  Widget _buildCustomAiHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121216) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF24242C) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Glowing Gradient AI Logo Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Live Status Indicator
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'StudentHub AI',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // Live green
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Online • Always active for campus help',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Modern "New Chat" Action (replaces the old circular refresh icon)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _initWelcomeMessage();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✨ Started a new AI conversation'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1F28) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF323242) : const Color(0xFFDBEAFE),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                    color: isDark ? Colors.blue.shade300 : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'New Chat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.blue.shade300 : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage msg, bool isDark, Color primaryColor) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
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
        margin: const EdgeInsets.only(bottom: 16, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top action bar (copy button only, no model badge)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                            ),
                            tooltip: 'Copy answer',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: msg.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied response to clipboard'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Styled Markdown rendering for headlines, subtitles, bullets, and clean bold text
                        MarkdownBody(
                          data: msg.text,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF1E293B),
                              height: 1.45,
                            ),
                            h1: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                              height: 1.4,
                            ),
                            h2: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                              height: 1.35,
                            ),
                            h3: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                              height: 1.35,
                            ),
                            strong: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            em: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                            listBullet: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                            ),
                            blockSpacing: 10,
                            tableBorder: TableBorder.all(
                              color: isDark ? const Color(0xFF2E2E3A) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            tableHead: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            tableBody: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                            code: TextStyle(
                              backgroundColor: isDark ? const Color(0xFF101014) : const Color(0xFFF1F5F9),
                              fontSize: 12,
                              color: isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Interactive clickable citation cards linking directly to the standalone post page
            if (msg.citations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📌 Cited Campus Resources (Tap to View):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...msg.citations.map((post) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // Opens individual post page
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
                              const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.grey),
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
