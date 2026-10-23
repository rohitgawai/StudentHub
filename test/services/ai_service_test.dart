import 'package:flutter_test/flutter_test.dart';
import 'package:student_hub/models/post_model.dart';
import 'package:student_hub/models/user_model.dart';
import 'package:student_hub/services/ai_service.dart';

void main() {
  group('AiService Resilience & Campus Engine Tests', () {
    final samplePosts = [
      PostModel(
        id: 'pst_scholarship_nsp_2026',
        title: '🚨 URGENT NOTICE: Post-Matric Scholarship Scheme 2026-27 (Mandatory NSP Application)',
        description: 'Mandatory NSP application for First Year Fresh OBC, SBC, VJNT students.',
        category: PostCategory.urgent,
        department: 'All Departments',
        authorName: 'Dr. Nilesh Patil (Director & Principal)',
        authorRole: UserRole.admin,
        authorId: 'fac_director_mit',
        timestamp: DateTime.now(),
        isUrgent: true,
      ),
      PostModel(
        id: 'pst_techyug_2026',
        title: '🚀 TECHयुग 2K26: State-Level Project Exhibition & Competition (Hybrid Mode)',
        description: 'Annual project competition at MIT CSN Campus.',
        category: PostCategory.event,
        department: 'Computer Science & Engineering',
        authorName: 'Vedant Tawade (CSI Lead)',
        authorRole: UserRole.eventHost,
        authorId: 'usr_vedant_tawade',
        timestamp: DateTime.now(),
        eventDate: DateTime(2026, 11, 24),
        venue: 'MIT CSN Campus',
      ),
    ];

    test('AiService answers "any notice?" dynamically and cites scholarship notice', () async {
      final res = await AiService.instance.ask(
        query: 'any notice?',
        posts: samplePosts,
      );

      expect(res.text.isNotEmpty, isTrue);
      expect(
        res.text.contains("trouble connecting to the campus intelligent engine"),
        isFalse,
        reason: 'Should provide real notices instead of broken connection message',
      );
      expect(res.citedPostIds.contains('pst_scholarship_nsp_2026'), isTrue);
    });

    test('AiService answers "any events?" dynamically and cites active events', () async {
      final res = await AiService.instance.ask(
        query: 'any events?',
        posts: samplePosts,
      );

      expect(res.text.isNotEmpty, isTrue);
      expect(
        res.text.contains("trouble connecting to the campus intelligent engine"),
        isFalse,
      );
      expect(res.citedPostIds.contains('pst_techyug_2026'), isTrue);
    });

    test('AiService provides structured study tips for "how to pass"', () async {
      final res = await AiService.instance.ask(
        query: 'is there any tip to get pass?',
        posts: samplePosts,
      );

      expect(res.text.isNotEmpty, isTrue);
      expect(
        res.text.contains("trouble connecting to the campus intelligent engine"),
        isFalse,
      );
      final lower = res.text.toLowerCase();
      expect(
        lower.contains('exam') || lower.contains('study') || lower.contains('pass') || lower.contains('paper'),
        isTrue,
        reason: 'Should provide actionable academic study or passing guidance',
      );
    });

    test('AiService protects student privacy when phone number is requested', () async {
      final res = await AiService.instance.ask(
        query: 'what is the coordinator phone number?',
        posts: samplePosts,
      );

      expect(res.text.contains('cannot share personal phone numbers'), isTrue);
      expect(res.citedPostIds.isEmpty, isTrue);
    });
  });
}
