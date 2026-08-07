import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mock_data_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginComplete;

  const AuthScreen({super.key, required this.onLoginComplete});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isSignUp = false;

  final nameController = TextEditingController(text: 'Aarav Sharma');
  final emailController = TextEditingController(text: 'aarav.sharma@studenthub.edu');
  final idController = TextEditingController(text: 'MIT/CS/2023/042');
  final mobileController = TextEditingController(text: '+91 98765 12345');
  
  late String selectedDepartment;
  late String selectedYear;

  @override
  void initState() {
    super.initState();
    final cfg = Provider.of<MockDataService>(context, listen: false).config;
    selectedDepartment = cfg.departments.first;
    selectedYear = cfg.academicYears[2];
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    idController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final cfg = dataService.config;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo & Header
                    Icon(Icons.school_rounded, size: 64, color: cfg.primaryColor),
                    const SizedBox(height: 12),
                    Text(
                      cfg.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: cfg.primaryColor,
                      ),
                    ),
                    Text(
                      cfg.tagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      backgroundColor: cfg.primaryColor.withValues(alpha: 0.1),
                      label: Text(
                        cfg.collegeName,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cfg.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    Text(
                      isSignUp ? 'Create Campus Account' : 'Welcome Back Student',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    if (isSignUp) ...[
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'College Email ID',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.length < 4 ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 12),

                    if (isSignUp) ...[
                      TextFormField(
                        controller: idController,
                        decoration: const InputDecoration(
                          labelText: 'Student / Employee ID',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: selectedDepartment,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: cfg.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedDepartment = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          border: OutlineInputBorder(),
                        ),
                        items: cfg.academicYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedYear = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: mobileController,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: cfg.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;

                        if (isSignUp) {
                          dataService.initializeNewUser(
                            id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
                            studentOrEmployeeId: idController.text.trim(),
                            department: selectedDepartment,
                            year: selectedYear,
                            mobileNumber: mobileController.text.trim(),
                            avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=256',
                          );
                        }

                        widget.onLoginComplete();
                      },
                      child: Text(
                        isSignUp ? 'Sign Up & Continue' : 'Log In to Campus',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () => setState(() => isSignUp = !isSignUp),
                      child: Text(
                        isSignUp
                            ? 'Already have an account? Log In'
                            : 'Don\'t have an account? Sign Up as Student',
                      ),
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
