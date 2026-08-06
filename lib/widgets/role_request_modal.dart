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
                      'Request permissions to post events or departmental notices. Admin approval is required.',
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

                dataService.submitRoleRequest(
                  requestedRole: requestedRole,
                  reason: reasonController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
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
