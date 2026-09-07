import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';

class AiCitation {
  final String postId;
  final String title;
  final String category;

  const AiCitation({
    required this.postId,
    required this.title,
    required this.category,
  });
}

class AiResponse {
  final String text;
  final List<String> citedPostIds;
  final String providerUsed; // 'Gemini 3.6 Flash' or 'Groq (Llama/GPT)'

  const AiResponse({
    required this.text,
    required this.citedPostIds,
    required this.providerUsed,
  });
}

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const String _geminiApiKey =
      'AQ.Ab8RN6K0bzZoLiVVqA6wCwDsd8y9CYeNxjXDyArse7bfcnRVXQ';
  static const String _groqApiKey =
      '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';

  // Cache for fetched profile records to enrich coordinator information
  final Map<String, Map<String, dynamic>> _profileCache = {};

  /// System prompt strictly scoping StudentHub AI to campus/academic subjects only.
  static const String _systemPrompt = '''
You are StudentHub AI, the official, intelligent, and dedicated campus assistant for StudentHub.

STRICT OPERATIONAL GUIDELINES & BOUNDARIES:
1. SCOPE RESTRICTION: You MUST limit your answers to campus information, university notices, college events, workshops, hackathons, scholarships, exam schedules, course materials, college fees, student activities, and academic subjects.
2. EXPLICIT & UNNECESSARY CONTENT REJECTION:
   - If the user asks anything explicit, sexual, inappropriate, harmful, abusive, or completely out-of-scope non-college topics, you MUST politely and firmly refuse:
     "I am StudentHub AI, your dedicated campus assistant. I can only assist with college notices, events, academics, exams, and campus activities."
3. STRICT PRIVACY, HARASSMENT PREVENTION & CONTACT PROTECTION (ZERO-TOLERANCE):
   - You MUST NEVER search for, browse, output, or disclose any personal phone numbers, mobile numbers, WhatsApp numbers, or private emails of any student, female coordinator, faculty, or campus user under ANY circumstances.
   - If a user asks for someone's contact number, phone number, or personal email (e.g., "Give me the coordinator's number/email", "What is her phone number?"), you MUST refuse:
     "For student safety, privacy, and harassment prevention, I cannot share personal phone numbers or contact details of students or coordinators. You can connect with event organizers directly through the official campus department or the StudentHub event page."
4. PASSING & EXAM ADVICE / WELLNESS:
   - If a student asks "is there any tip to get pass?", "how to pass", or asks for study tips, provide practical, encouraging, and academic advice (e.g., analyze previous year question papers, focus on core syllabus weightage, master important definitions/diagrams, form focused study sessions, and reach out to faculty for doubts). Keep it motivating and structured.
   - If a student expresses fatigue or stress (e.g., "I'm feeling tired"), offer warm, practical wellness advice (hydration, short breaks, pacing study) without unnecessarily citing or listing unrelated campus posts.
5. NO UNRELATED DATA DUMPING & NO RAW BACKEND LISTS (CRITICAL):
   - If the user asks about a specific topic, event, competition, or keyword (such as "hackathons", "internships", "scholarships", or specific subjects) and NO matching post exists on StudentHub:
     • Explicitly and politely state that there are currently no active announcements or posts for that specific topic on StudentHub.
     • Advise the user to check back soon or keep notifications enabled, as organizers and departments post new updates frequently.
     • ZERO-TOLERANCE: NEVER dump unrelated events, tables of other posts, or backend database rows just to fill the answer. Never say "The only upcoming events we have are: [list of other unrelated events]" when the user asked for a different topic!
     • NEVER expose raw database dumps, backend schema IDs, or lists of internal test posts.
6. AVOID DUMMY / TEST POSTS:
   - Completely ignore and never mention dummy, test, or spam posts (e.g. posts with titles like "hehe", "ge", "t66", "heyehehe", etc.). Never include them in any response.
7. DATA REASONING (MATCHING POSTS, EVENTS, WORKSHOPS, PDFS, PROFILES):
   - Only when a post genuinely matches the user's query, provide accurate details:
     • For events/workshops: state the title, date, venue, registration deadline, and coordinator name/department. Never provide personal phone numbers or private email addresses.
     • For notices with attachments: mention the document title and note that the student can view or download it from the post card.
8. FORMATTING & PRESENTATION:
   - Use clean, proper Markdown headings (`### Subtitle` or `## Headline`) for sections rather than raw asterisks.
   - Use bullet points with `-` or numbered lists.
   - Bold key terms with `**text**` cleanly.
   - Maintain a friendly, supportive, and polished tone.
''';

  static bool _isDummyPost(PostModel p) {
    final t = p.title.trim().toLowerCase();
    if (t.length < 3) return true;
    if (t == 'hehe' ||
        t == 'heyehehe' ||
        t == 'ge' ||
        t == 'gege' ||
        t == 't66' ||
        t == 'test' ||
        t == 'testing' ||
        t == 'asdf') {
      return true;
    }
    if (t.startsWith('event "') || t.startsWith('workshop "')) {
      // Check if inner title is dummy like "hehe"
      if (t.contains('hehe') || t.contains('t66') || t.contains('ge')) return true;
    }
    return false;
  }

  /// Prepares clean campus context excluding dummy posts and private contact info.
  Future<String> _buildCampusContext(List<PostModel> posts) async {
    final client = Supabase.instance.client;

    // Filter out dummy test posts
    final genuinePosts = posts.where((p) => !_isDummyPost(p)).toList();

    // Extract unique author/coordinator IDs
    final authorIds = genuinePosts
        .map((p) => p.authorId)
        .where((id) => id.isNotEmpty && !_profileCache.containsKey(id))
        .toSet()
        .toList();

    if (authorIds.isNotEmpty) {
      try {
        final rows = await client
            .from('profiles')
            .select('user_id, name, department, year, roles')
            .filter('user_id', 'in', authorIds)
            .timeout(const Duration(seconds: 4));

        for (final r in rows) {
          final uid = r['user_id']?.toString() ?? '';
          if (uid.isNotEmpty) {
            _profileCache[uid] = r;
          }
        }
      } catch (_) {}
    }

    final buffer = StringBuffer();
    buffer.writeln('=== CURRENT PUBLISHED CAMPUS ANNOUNCEMENTS ===');

    // Include top 25 genuine campus items
    final subset = genuinePosts.take(25);
    for (final p in subset) {
      buffer.writeln('---');
      buffer.writeln('Title: ${p.title}');
      buffer.writeln('Category: ${p.category.displayName}');
      buffer.writeln('Department: ${p.department}');
      if (p.targetYear != null) buffer.writeln('Target Year: ${p.targetYear}');
      buffer.writeln('Author/Coordinator: ${p.authorName} (${p.authorRole.name})');

      final prof = _profileCache[p.authorId];
      if (prof != null) {
        final dept = prof['department']?.toString() ?? '';
        final year = prof['year']?.toString() ?? '';
        buffer.writeln('Coordinator Profile -> Dept: $dept, Year: $year');
      }

      if (p.isEvent) {
        if (p.eventDate != null) buffer.writeln('Event Date: ${p.eventDate}');
        if (p.venue != null) buffer.writeln('Venue: ${p.venue}');
        if (p.registrationDeadline != null) buffer.writeln('Reg Deadline: ${p.registrationDeadline}');
        if (p.maxParticipants != null) {
          buffer.writeln('Slots: ${p.currentRegistrations}/${p.maxParticipants}');
        }
      }

      if (p.attachments.isNotEmpty) {
        final attNames = p.attachments.map((a) => '${a.title} (${a.fileType})').join(', ');
        buffer.writeln('Attached Documents/PDFs: $attNames');
      }

      if (p.imageUrl != null || p.imageUrls.isNotEmpty) {
        final count = (p.imageUrl != null ? 1 : 0) + p.imageUrls.length;
        buffer.writeln('Images Attached: $count photo(s)');
      }

      if (p.links.isNotEmpty) {
        final linksStr = p.links.map((l) => '${l.label}: ${l.url}').join(', ');
        buffer.writeln('External Links: $linksStr');
      }

      buffer.writeln('Description/Details: ${p.description}');
    }

    buffer.writeln('=== END OF ANNOUNCEMENTS ===');
    return buffer.toString();
  }

  /// Finds relevant post IDs to present as clickable citation cards in the UI.
  /// Strictly avoids attaching irrelevant posts or test records.
  List<String> _extractCitations(String query, String aiAnswer, List<PostModel> posts) {
    final lowerQ = query.toLowerCase();
    final lowerAns = aiAnswer.toLowerCase();

    // If query is conversational, general greeting, wellness, or pass tips, do NOT cite campus posts
    if (lowerQ.contains('tired') ||
        lowerQ.contains('feeling') ||
        lowerQ.contains('hello') ||
        lowerQ.contains('hi ') ||
        lowerQ.contains('who are you') ||
        lowerQ.contains('tip to get pass') ||
        lowerQ.contains('how to pass')) {
      return [];
    }

    // If AI explicitly says there are no posts/hackathons/scholarships, do NOT attach unrelated citations
    if (lowerAns.contains('no hackathon') ||
        lowerAns.contains('no active') ||
        lowerAns.contains('not listed') ||
        lowerAns.contains('hasn\'t been posted') ||
        lowerAns.contains('no scholarship') ||
        lowerAns.contains('no announcements')) {
      return [];
    }

    final matchedIds = <String>{};

    for (final p in posts) {
      if (_isDummyPost(p)) continue;
      final pTitle = p.title.trim().toLowerCase();
      if (pTitle.length < 4) continue;

      // Check if AI explicitly mentions the post title in quotes, bold, or as a distinct phrase
      final isQuotedOrBold = lowerAns.contains('**$pTitle**') ||
          lowerAns.contains('"$pTitle"') ||
          lowerAns.contains('\'$pTitle\'');

      final hasExactTitle = lowerAns.contains(pTitle) &&
          (pTitle.length >= 8 || isQuotedOrBold);

      if (hasExactTitle) {
        matchedIds.add(p.id);
      }
    }

    return matchedIds.take(3).toList();
  }

  /// Sends the prompt to Google Gemini 3.6 Flash.
  Future<String?> _callGemini({
    required String query,
    required String context,
    List<Map<String, String>> history = const [],
    http.Client? client,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$_geminiApiKey',
    );

    final contents = <Map<String, dynamic>>[];

    // History
    for (final h in history.take(6)) {
      contents.add({
        'role': h['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': h['text'] ?? ''}
        ],
      });
    }

    // Current query with context
    contents.add({
      'role': 'user',
      'parts': [
        {
          'text': '''
$context

User Question: "$query"
Please answer using the campus announcements and guidance above.
'''
        }
      ],
    });

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': _systemPrompt}
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.35,
        'maxOutputTokens': 1200,
      },
    };

    final httpClient = client ?? http.Client();
    try {
      final res = await httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 14));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
      debugPrint('StudentHub AI: Gemini failed with ${res.statusCode}: ${res.body}');
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Fallback: Sends the prompt to Groq Cloud (openai/gpt-oss-20b).
  Future<String?> _callGroq({
    required String query,
    required String context,
    List<Map<String, String>> history = const [],
    http.Client? client,
  }) async {
    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
    ];

    for (final h in history.take(6)) {
      messages.add({
        'role': h['role'] == 'user' ? 'user' : 'assistant',
        'content': h['text'] ?? '',
      });
    }

    messages.add({
      'role': 'user',
      'content': '''
$context

User Question: "$query"
Please answer according to the campus instructions and guidelines.
''',
    });

    final payload = {
      'model': 'openai/gpt-oss-20b',
      'messages': messages,
      'temperature': 0.35,
      'max_tokens': 1200,
    };

    final httpClient = client ?? http.Client();
    try {
      final res = await httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 14));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final text = json['choices']?[0]?['message']?['content'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
      debugPrint('StudentHub AI: Groq failed with ${res.statusCode}: ${res.body}');
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Master method that calls Gemini 3.6 Flash first, with seamless automatic
  /// failover to Groq if Gemini is rate-limited or unavailable.
  Future<AiResponse> ask({
    required String query,
    required List<PostModel> posts,
    List<Map<String, String>> history = const [],
    http.Client? client,
  }) async {
    final contextStr = await _buildCampusContext(posts);

    // 1. Try Google Gemini 3.6 Flash
    try {
      final geminiReply = await _callGemini(
        query: query,
        context: contextStr,
        history: history,
        client: client,
      );
      if (geminiReply != null && geminiReply.isNotEmpty) {
        final citations = _extractCitations(query, geminiReply, posts);
        return AiResponse(
          text: geminiReply,
          citedPostIds: citations,
          providerUsed: 'Gemini 3.6 Flash',
        );
      }
    } catch (e) {
      if (e is http.ClientException) rethrow;
      debugPrint('StudentHub AI: Gemini call exception: $e');
    }

    // 2. Seamless Failover to Groq
    try {
      final groqReply = await _callGroq(
        query: query,
        context: contextStr,
        history: history,
        client: client,
      );
      if (groqReply != null && groqReply.isNotEmpty) {
        final citations = _extractCitations(query, groqReply, posts);
        return AiResponse(
          text: groqReply,
          citedPostIds: citations,
          providerUsed: 'Groq Cloud',
        );
      }
    } catch (e) {
      if (e is http.ClientException) rethrow;
      debugPrint('StudentHub AI: Groq call exception: $e');
    }

    // 3. Graceful offline fallback
    return AiResponse(
      text:
          "I'm having trouble connecting to the campus intelligent engine right now. Please check your internet connection or browse the latest updates directly in the Discover tab.",
      citedPostIds: [],
      providerUsed: 'Offline',
    );
  }
}
