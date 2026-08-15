import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/post_model.dart';


class AppConfig {
  String appName;
  String tagline;
  String collegeName;
  String collegeShortCode;
  String primaryColorHex;
  String eventColorHex;
  String urgentColorHex;
  String achievementColorHex;
  String successColorHex;
  String generalColorHex;
  String academicColorHex;
  String contactEmail;
  String supportPhone;
  List<String> departments;
  List<String> academicYears;
  List<String> postCategories;
  bool allowRoleSelfApplication;
  bool enablePdfAttachments;

  AppConfig({
    required this.appName,
    required this.tagline,
    required this.collegeName,
    required this.collegeShortCode,
    required this.primaryColorHex,
    required this.eventColorHex,
    required this.urgentColorHex,
    required this.achievementColorHex,
    required this.successColorHex,
    required this.generalColorHex,
    required this.academicColorHex,
    required this.contactEmail,
    required this.supportPhone,
    required this.departments,
    required this.academicYears,
    required this.postCategories,
    required this.allowRoleSelfApplication,
    required this.enablePdfAttachments,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      appName: json['appName'] ?? 'StudentHub',
      tagline: json['tagline'] ?? 'Digital Campus Platform',
      collegeName: json['collegeName'] ?? 'Campus Institute',
      collegeShortCode: json['collegeShortCode'] ?? 'CAMPUS',
      primaryColorHex: json['primaryColorHex'] ?? '#1E88E5',
      eventColorHex: json['eventColorHex'] ?? '#FB8C00',
      urgentColorHex: json['urgentColorHex'] ?? '#E53935',
      achievementColorHex: json['achievementColorHex'] ?? '#8E24AA',
      successColorHex: json['successColorHex'] ?? '#4CAF50',
      generalColorHex: json['generalColorHex'] ?? '#37474F',
      academicColorHex: json['academicColorHex'] ?? '#0288D1',
      contactEmail: json['contactEmail'] ?? 'support@studenthub.edu',
      supportPhone: json['supportPhone'] ?? '+91 98765 43210',
      departments: List<String>.from(json['departments'] ?? [
        'Computer Science & Engineering',
        'Information Technology',
        'Electronics & Communication',
        'Mechanical Engineering',
        'Civil Engineering',
        'Management Studies'
      ]),
      academicYears: List<String>.from(json['academicYears'] ?? [
        'First Year',
        'Second Year',
        'Third Year',
        'Final Year',
        'Postgraduate'
      ]),
      postCategories: List<String>.from(json['postCategories'] ?? [
        'Announcement',
        'Event',
        'Academic',
        'Workshop',
        'Achievement',
        'Gallery',
        'Placement',
        'Urgent'
      ]),
      allowRoleSelfApplication: json['allowRoleSelfApplication'] ?? true,
      enablePdfAttachments: json['enablePdfAttachments'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'tagline': tagline,
      'collegeName': collegeName,
      'collegeShortCode': collegeShortCode,
      'primaryColorHex': primaryColorHex,
      'eventColorHex': eventColorHex,
      'urgentColorHex': urgentColorHex,
      'achievementColorHex': achievementColorHex,
      'successColorHex': successColorHex,
      'generalColorHex': generalColorHex,
      'academicColorHex': academicColorHex,
      'contactEmail': contactEmail,
      'supportPhone': supportPhone,
      'departments': departments,
      'academicYears': academicYears,
      'postCategories': postCategories,
      'allowRoleSelfApplication': allowRoleSelfApplication,
      'enablePdfAttachments': enablePdfAttachments,
    };
  }

  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Color get primaryColor => hexToColor(primaryColorHex);
  Color get eventColor => hexToColor(eventColorHex);
  Color get urgentColor => hexToColor(urgentColorHex);
  Color get achievementColor => hexToColor(achievementColorHex);
  Color get successColor => hexToColor(successColorHex);
  Color get generalColor => hexToColor(generalColorHex);
  Color get academicColor => hexToColor(academicColorHex);

  /// Reserved color system for post categories:
  /// 🔴 Urgent · 🟠 Events · 🔵 Academic · 🟢 Success · 🟣 Achievement.
  Color colorForCategory(PostCategory category) {
    switch (category) {
      case PostCategory.urgent:
        return urgentColor;
      case PostCategory.event:
      case PostCategory.workshop:
        return eventColor;
      case PostCategory.academic:
      case PostCategory.announcement:
        return academicColor;
      case PostCategory.placement:
        return successColor;
      case PostCategory.gallery:
        return generalColor;
      case PostCategory.achievement:
        return achievementColor;
    }
  }

  static Future<AppConfig> loadFromAssets() async {
    try {
      final jsonString = await rootBundle.loadString('assets/config/app_config.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      return AppConfig.fromJson(jsonMap);
    } catch (e) {
      return AppConfig.defaultConfig();
    }
  }

  static AppConfig defaultConfig() {
    return AppConfig(
      appName: 'StudentHub',
      tagline: 'Digital Campus Platform',
      collegeName: 'St. Andrew Institute of Technology & Science',
      collegeShortCode: 'MIT',
      primaryColorHex: '#1E88E5',
      eventColorHex: '#FB8C00',
      urgentColorHex: '#E53935',
      achievementColorHex: '#8E24AA',
      successColorHex: '#4CAF50',
      generalColorHex: '#37474F',
      academicColorHex: '#0288D1',
      contactEmail: 'support@studenthub.edu',
      supportPhone: '+91 98765 43210',
      departments: [
        'Computer Science & Engineering',
        'Information Technology',
        'Electronics & Communication',
        'Mechanical Engineering',
        'Civil Engineering',
        'Management Studies'
      ],
      academicYears: [
        'First Year',
        'Second Year',
        'Third Year',
        'Final Year',
        'Postgraduate'
      ],
      postCategories: [
        'Announcement',
        'Event',
        'Academic',
        'Workshop',
        'Achievement',
        'Gallery',
        'Placement',
        'Urgent'
      ],
      allowRoleSelfApplication: true,
      enablePdfAttachments: true,
    );
  }
}
