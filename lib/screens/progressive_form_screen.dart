import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_file_service.dart';
import '../services/mock_data_service.dart';
import '../widgets/app_image.dart';
import '../widgets/mit_id_input_field.dart';

class ProgressiveFormScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const ProgressiveFormScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<ProgressiveFormScreen> createState() => _ProgressiveFormScreenState();
}

class _ProgressiveFormScreenState extends State<ProgressiveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;

  String _avatarUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=256';
  late String _selectedDepartment;
  late String _selectedYear;
  final _idController = TextEditingController(text: 'MIT25-A-03-UG-CSE-47484');

  @override
  void initState() {
    super.initState();
    final dataService = Provider.of<MockDataService>(context, listen: false);
    final user = dataService.currentUser;
    final cfg = dataService.config;

    if (user.avatarUrl.isNotEmpty) {
      _avatarUrl = user.avatarUrl;
    }
    _selectedDepartment = user.department.isNotEmpty && cfg.departments.contains(user.department)
        ? user.department
        : cfg.departments.first;

    _selectedYear = user.year.isNotEmpty && cfg.academicYears.contains(user.year)
        ? user.year
        : cfg.academicYears.first;

    if (user.studentOrEmployeeId.isNotEmpty) {
      _idController.text = user.studentOrEmployeeId;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await pickImageFromDevice();
      if (picked != null && picked.source != null) {
        if (!mounted) return;
        setState(() {
          _avatarUrl = picked.source!;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Could not open photo library.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final dataService = Provider.of<MockDataService>(context, listen: false);

    try {
      await dataService.completeProgressiveForm(
        avatarUrl: _avatarUrl,
        department: _selectedDepartment,
        year: _selectedYear,
        studentOrEmployeeId: _idController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Academic profile saved to device & server successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  double get _progressValue => (_currentStep + 1) / 3.0;

  void _confirmLogout(MockDataService dataService) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text(
          'Go back to the login screen? Your academic setup will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              dataService.logout(
                reason: 'Logged out from academic setup.',
              );
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final cfg = dataService.config;

return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Academic Setup'),
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Log out and go back to login',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(dataService),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amazing Progress Bar Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cfg.primaryColor, cfg.primaryColor.withBlue(210)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: cfg.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Step ${_currentStep + 1} of 3',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(_progressValue * 100).toInt()}% Completed',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Animated Progress Indicator Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              height: 8,
                              child: LinearProgressIndicator(
                                value: _progressValue,
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            _currentStep == 0
                                ? 'Upload Profile Photo'
                                : _currentStep == 1
                                    ? 'Select Department & Year'
                                    : 'Enter MIT Unique ID',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'One-time setup for synchronization with campus server',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Step 1: Profile Picture
                    if (_currentStep == 0) ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Text(
                                'Set Your Campus Profile Picture',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'This photo will be displayed on your digital ID card & campus posts.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 20),

                              Center(
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 54,
                                      backgroundColor: cfg.primaryColor.withValues(alpha: 0.1),
                                      child: ClipOval(
                                        child: _avatarUrl.isNotEmpty
                                            ? AppImage(
                                                source: _avatarUrl,
                                                width: 108,
                                                height: 108,
                                                fit: BoxFit.cover,
                                              )
                                            : Icon(
                                                Icons.person,
                                                size: 54,
                                                color: cfg.primaryColor,
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: InkWell(
                                        onTap: _pickAvatar,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: cfg.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  side: BorderSide(color: cfg.primaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text(
                                  'Upload Photo',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: _pickAvatar,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Step 2: Department & Academic Year
                    if (_currentStep == 1) ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Academic Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              DropdownButtonFormField<String>(
                                initialValue: _selectedDepartment,
                                decoration: InputDecoration(
                                  labelText: 'Department',
                                  prefixIcon: const Icon(Icons.school),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: cfg.departments
                                    .map((d) => DropdownMenuItem(
                                          value: d,
                                          child: Text(d, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedDepartment = val);
                                },
                              ),
                              const SizedBox(height: 16),

                              DropdownButtonFormField<String>(
                                initialValue: _selectedYear,
                                decoration: InputDecoration(
                                  labelText: 'Academic Year',
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: cfg.academicYears
                                    .map((y) => DropdownMenuItem(
                                          value: y,
                                          child: Text(y),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedYear = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Step 3: MIT Unique ID
                    if (_currentStep == 2) ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enter Campus Unique Identification',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Enter your official MIT Unique ID / Roll Number or Employee Code.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),

                              MitIdInputField(
                                initialValue: _idController.text,
                                department: _selectedDepartment,
                                year: _selectedYear,
                                onChanged: (val) {
                                  _idController.text = val;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Controls Bottom Row
                    Row(
                      children: [
                        if (_currentStep > 0) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => setState(() => _currentStep--),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: cfg.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    if (_currentStep < 2) {
                                      setState(() => _currentStep++);
                                    } else {
                                      _submitForm();
                                    }
                                  },
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _currentStep < 2 ? 'Continue Step' : 'Submit & Enter Home',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
