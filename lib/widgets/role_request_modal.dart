import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import 'custom_dropdown.dart';

class RoleRequestModal extends StatefulWidget {
  const RoleRequestModal({super.key});

  @override
  State<RoleRequestModal> createState() => _RoleRequestModalState();
}

class _RoleRequestModalState extends State<RoleRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  final phoneController = TextEditingController();

  UserRole? requestedRole;
  bool isLimitedAccess = false;
  int? durationDays;

  static const Map<String, int> durationOptions = {
    '1 Week': 7,
    '1 Month': 30,
    '3 Months': 90,
    '6 Months': 180,
  };

  @override
  void initState() {
    super.initState();
    final user = Provider.of<MockDataService>(context, listen: false).currentUser;
    phoneController.text = user.mobileNumber;

    // Requirement 1 & 7: Filter available roles user doesn't possess yet
    final availableRoles = [UserRole.eventHost, UserRole.faculty]
        .where((r) => !user.hasRole(r))
        .toList();
    if (availableRoles.isNotEmpty) {
      requestedRole = availableRoles.first;
    }
  }

  @override
  void dispose() {
    reasonController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;

    // Filter roles user does not possess
    final availableRoles = [UserRole.eventHost, UserRole.faculty]
        .where((r) => !user.hasRole(r))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Role Permission'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: availableRoles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      'All Role Permissions Granted!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You already hold active Event Host and Faculty permissions on your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Return to Profile'),
                    ),
                  ],
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.verified_user_outlined, color: Colors.amber, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Request permissions to post events or departmental notices. Admin approval is required. Event Host access can be permanent or limited-time (auto-expires).',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Select Role (Only shows roles NOT already held)
                  CustomDropdownField<UserRole>(
                    value: requestedRole ?? availableRoles.first,
                    labelText: 'Target Role Request',
                    prefixIcon: Icons.admin_panel_settings_outlined,
                    items: availableRoles,
                    itemLabel: (role) {
                      switch (role) {
                        case UserRole.eventHost:
                          return 'Event Host (Create events & manage registrations)';
                        case UserRole.faculty:
                          return 'Faculty (Academic notices & department updates)';
                        default:
                          return role.displayName;
                      }
                    },
                    onChanged: (val) {
                      if (val != null) setState(() => requestedRole = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Access Term Selector (Event Host only)
                  if ((requestedRole ?? availableRoles.first) == UserRole.eventHost) ...[
                    const Text(
                      'Access Term',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Permanent'),
                          icon: Icon(Icons.all_inclusive, size: 16),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Limited Time'),
                          icon: Icon(Icons.timer, size: 16),
                        ),
                      ],
                      selected: {isLimitedAccess},
                      onSelectionChanged: (selection) {
                        setState(() => isLimitedAccess = selection.first);
                        if (!selection.first) durationDays = null;
                      },
                    ),
                    if (isLimitedAccess) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Choose duration:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: durationOptions.entries.map((entry) {
                          final isSelected = durationDays == entry.value;
                          return ChoiceChip(
                            label: Text(entry.key),
                            selected: isSelected,
                            selectedColor: dataService.config.primaryColor.withValues(alpha: 0.2),
                            onSelected: (_) {
                              setState(() => durationDays = entry.value);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 4),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Pre-filled Info
                  TextFormField(
                    initialValue: user.name,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Applicant Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: user.studentOrEmployeeId,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Student / Employee ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: user.department,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter contact phone' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: reasonController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Permission Request *',
                      hintText: 'e.g. I am President of Coding Club / Faculty coordinator...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please explain your reason' : null,
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: dataService.config.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

                      if (isLimitedAccess && durationDays == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a duration for limited-time access.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      dataService.submitRoleRequest(
                        requestedRole: requestedRole ?? availableRoles.first,
                        reason: reasonController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        isLimitedAccess: isLimitedAccess,
                        durationDays: durationDays,
                      );

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Role request submitted to Admin! Track status in Profile.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
