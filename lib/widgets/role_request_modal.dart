import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';

class RoleRequestModal extends StatefulWidget {
  const RoleRequestModal({super.key});

  @override
  State<RoleRequestModal> createState() => _RoleRequestModalState();
}

class _RoleRequestModalState extends State<RoleRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  final phoneController = TextEditingController();

  UserRole requestedRole = UserRole.eventHost;
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
      body: Form(
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

            // Select Role
            DropdownButtonFormField<UserRole>(
              value: requestedRole,
              decoration: const InputDecoration(
                labelText: 'Target Role Request',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: UserRole.eventHost,
                  child: Text('Event Host (Create events & manage registrations)'),
                ),
                DropdownMenuItem(
                  value: UserRole.faculty,
                  child: Text('Faculty (Academic notices & department updates)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => requestedRole = val);
              },
            ),
            const SizedBox(height: 16),

            // Access Term Selector (Event Host only)
            if (requestedRole == UserRole.eventHost) ...[
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
                      selectedColor: dataService.config.primaryColor.withOpacity(0.2),
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
                  requestedRole: requestedRole,
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
