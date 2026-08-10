import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mock_data_service.dart';
import 'custom_dropdown.dart';

class EditProfileModal extends StatefulWidget {
  const EditProfileModal({super.key});

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController idController;
  late TextEditingController mobileController;
  late String selectedDepartment;
  late String selectedYear;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<MockDataService>(context, listen: false).currentUser;
    nameController = TextEditingController(text: user.name);
    idController = TextEditingController(text: user.studentOrEmployeeId);
    mobileController = TextEditingController(text: user.mobileNumber);
    selectedDepartment = user.department;
    selectedYear = user.year;
  }

  @override
  void dispose() {
    nameController.dispose();
    idController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;
    final cfg = dataService.config;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '✏️ Edit Profile Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name (Enforcing "Name Surname" format)
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name * (Name Surname)',
                    hintText: 'e.g. Aarav Sharma',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter full name';
                    final words = v.trim().split(RegExp(r'\s+'));
                    if (words.length < 2) {
                      return 'Must be in "Name Surname" format (e.g. Aarav Sharma)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Department Custom Dropdown
                CustomDropdownField<String>(
                  value: selectedDepartment,
                  labelText: 'Department',
                  prefixIcon: Icons.school_outlined,
                  items: cfg.departments,
                  itemLabel: (d) => d,
                  onChanged: (val) {
                    if (val != null) setState(() => selectedDepartment = val);
                  },
                ),
                const SizedBox(height: 12),

                // Year Custom Dropdown
                CustomDropdownField<String>(
                  value: selectedYear,
                  labelText: 'Academic Year',
                  prefixIcon: Icons.calendar_today_outlined,
                  items: cfg.academicYears,
                  itemLabel: (y) => y,
                  onChanged: (val) {
                    if (val != null) setState(() => selectedYear = val);
                  },
                ),
                const SizedBox(height: 12),

                // Unique Student ID (Editable ONLY ONCE)
                TextFormField(
                  controller: idController,
                  enabled: !user.hasChangedUniqueId,
                  decoration: InputDecoration(
                    labelText: 'MIT Unique Student/Employee ID',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: const OutlineInputBorder(),
                    helperText: user.hasChangedUniqueId
                        ? '🔒 Locked: Unique ID can only be changed once'
                        : '⚠️ Note: Unique ID can be updated ONLY ONCE',
                    helperStyle: TextStyle(
                      color: user.hasChangedUniqueId ? Colors.red : Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Mobile Number (used for registrations & event contact)
                TextFormField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: 'e.g. +91 98765 43210',
                    prefixIcon: const Icon(Icons.phone_android_outlined),
                    border: const OutlineInputBorder(),
                    helperText:
                        'Shown to event hosts when you register for their events',
                    helperStyle: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Enter your mobile number';
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) {
                      return 'Enter a valid mobile number (10+ digits)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      backgroundColor: cfg.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

                      dataService.updateUserProfile(
                        name: nameController.text.trim(),
                        department: selectedDepartment,
                        year: selectedYear,
                        studentOrEmployeeId: idController.text.trim(),
                        mobileNumber: mobileController.text.trim(),
                      );

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Profile details updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
