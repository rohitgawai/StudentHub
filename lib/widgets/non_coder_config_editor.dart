import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/mock_data_service.dart';

class NonCoderConfigEditor extends StatefulWidget {
  const NonCoderConfigEditor({super.key});

  @override
  State<NonCoderConfigEditor> createState() => _NonCoderConfigEditorState();
}

class _NonCoderConfigEditorState extends State<NonCoderConfigEditor> {
  late TextEditingController appNameController;
  late TextEditingController taglineController;
  late TextEditingController collegeNameController;
  late TextEditingController bannerTextController;
  late TextEditingController primaryColorController;
  late TextEditingController eventColorController;
  late TextEditingController urgentColorController;
  late TextEditingController academicColorController;

  late bool enableUrgentBanner;
  late bool allowRoleSelfApplication;
  late bool enablePdfAttachments;

  @override
  void initState() {
    super.initState();
    final config = Provider.of<MockDataService>(context, listen: false).config;
    appNameController = TextEditingController(text: config.appName);
    taglineController = TextEditingController(text: config.tagline);
    collegeNameController = TextEditingController(text: config.collegeName);
    bannerTextController = TextEditingController(text: config.announcementBannerText);
    primaryColorController = TextEditingController(text: config.primaryColorHex);
    eventColorController = TextEditingController(text: config.eventColorHex);
    urgentColorController = TextEditingController(text: config.urgentColorHex);
    academicColorController = TextEditingController(text: config.academicColorHex);

    enableUrgentBanner = config.enableUrgentBanner;
    allowRoleSelfApplication = config.allowRoleSelfApplication;
    enablePdfAttachments = config.enablePdfAttachments;
  }

  @override
  void dispose() {
    appNameController.dispose();
    taglineController.dispose();
    collegeNameController.dispose();
    bannerTextController.dispose();
    primaryColorController.dispose();
    eventColorController.dispose();
    urgentColorController.dispose();
    academicColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Non-Coder Platform Config'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Default Config',
            onPressed: () {
              dataService.updateConfig(AppConfig.defaultConfig());
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuration reset to defaults.')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: const [
                Icon(Icons.edit_note, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No Coding Required! Modify platform branding, campus titles, theme colors, and banner announcements in real-time.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 1: Branding & Info
          _buildSectionHeader('1. Branding & Institution'),
          TextField(
            controller: appNameController,
            decoration: const InputDecoration(
              labelText: 'Platform Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: taglineController,
            decoration: const InputDecoration(
              labelText: 'Tagline',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: collegeNameController,
            decoration: const InputDecoration(
              labelText: 'College / Institution Name',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),
          // Section 2: Colors
          _buildSectionHeader('2. Brand Colors (Hex Codes)'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: primaryColorController,
                  decoration: const InputDecoration(
                    labelText: 'Primary Color',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: eventColorController,
                  decoration: const InputDecoration(
                    labelText: 'Event Color',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: urgentColorController,
                  decoration: const InputDecoration(
                    labelText: 'Urgent Color',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: academicColorController,
                  decoration: const InputDecoration(
                    labelText: 'Academic Color',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Section 3: Banners & Feature Flags
          _buildSectionHeader('3. Campus Banners & Features'),
          SwitchListTile(
            title: const Text('Show Urgent Announcement Banner'),
            subtitle: const Text('Display highlighted ticker at top of feed'),
            value: enableUrgentBanner,
            onChanged: (val) => setState(() => enableUrgentBanner = val),
          ),
          if (enableUrgentBanner)
            TextField(
              controller: bannerTextController,
              decoration: const InputDecoration(
                labelText: 'Banner Text',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Allow Student Role Applications'),
            subtitle: const Text('Permit students to request Event Host / Faculty roles'),
            value: allowRoleSelfApplication,
            onChanged: (val) => setState(() => allowRoleSelfApplication = val),
          ),
          SwitchListTile(
            title: const Text('Enable PDF Attachments'),
            subtitle: const Text('Allow attached document preview modal'),
            value: enablePdfAttachments,
            onChanged: (val) => setState(() => enablePdfAttachments = val),
          ),

          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final newCfg = AppConfig(
                appName: appNameController.text.trim(),
                tagline: taglineController.text.trim(),
                collegeName: collegeNameController.text.trim(),
                collegeShortCode: dataService.config.collegeShortCode,
                primaryColorHex: primaryColorController.text.trim(),
                eventColorHex: eventColorController.text.trim(),
                urgentColorHex: urgentColorController.text.trim(),
                achievementColorHex: dataService.config.achievementColorHex,
                successColorHex: dataService.config.successColorHex,
                generalColorHex: dataService.config.generalColorHex,
                academicColorHex: academicColorController.text.trim(),
                contactEmail: dataService.config.contactEmail,
                supportPhone: dataService.config.supportPhone,
                enableUrgentBanner: enableUrgentBanner,
                announcementBannerText: bannerTextController.text.trim(),
                departments: dataService.config.departments,
                academicYears: dataService.config.academicYears,
                postCategories: dataService.config.postCategories,
                allowRoleSelfApplication: allowRoleSelfApplication,
                enablePdfAttachments: enablePdfAttachments,
              );

              dataService.updateConfig(newCfg);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✨ Platform Configuration & Design Updated Successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.check_circle),
            label: const Text(
              'Apply Changes Immediately',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }
}
