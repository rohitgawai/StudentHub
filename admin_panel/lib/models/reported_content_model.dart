class ReportedContentModel {
  final String id;
  final String postId;
  final String postContent;
  final String authorName;
  final String authorId;
  final String reporterName;
  final String reporterId;
  final String reportReason;
  final String status; // pending, resolved, dismissed
  final DateTime createdAt;

  ReportedContentModel({
    required this.id,
    required this.postId,
    required this.postContent,
    required this.authorName,
    required this.authorId,
    required this.reporterName,
    required this.reporterId,
    required this.reportReason,
    required this.status,
    required this.createdAt,
  });

  factory ReportedContentModel.fromMap(Map<String, dynamic> map) {
    return ReportedContentModel(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      postContent: map['post_content']?.toString() ?? map['content']?.toString() ?? '[No Text Content]',
      authorName: map['author_name']?.toString() ?? 'Student',
      authorId: map['author_id']?.toString() ?? '',
      reporterName: map['reporter_name']?.toString() ?? 'Anonymous Reporter',
      reporterId: map['reporter_id']?.toString() ?? '',
      reportReason: map['reason']?.toString() ?? map['report_reason']?.toString() ?? 'Inappropriate content',
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : DateTime.now(),
    );
  }
}
