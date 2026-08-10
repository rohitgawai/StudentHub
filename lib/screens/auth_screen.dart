import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mock_data_service.dart';
import '../widgets/app_image.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginComplete;

  const AuthScreen({super.key, required this.onLoginComplete});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showNewAccountForm = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final mobileController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({String? name, String? email, String? mobile}) async {
    final loginName = name ?? nameController.text.trim();
    final loginEmail = email ?? emailController.text.trim();
    final loginMobile = mobile ?? mobileController.text.trim();

    if (name == null && !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final dataService = Provider.of<MockDataService>(context, listen: false);

    try {
      await dataService.loginUser(
        name: loginName,
        email: loginEmail,
        mobileNumber: loginMobile,
      );
      if (mounted) {
        widget.onLoginComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Login error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final cfg = dataService.config;
    final lastUser = dataService.lastKnownUser;
    final hasLastUser = lastUser != null && lastUser.email.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Logo & Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cfg.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: 56,
                          color: cfg.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        cfg.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: cfg.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cfg.tagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: Chip(
                          backgroundColor: cfg.primaryColor.withValues(alpha: 0.08),
                          side: BorderSide(
                            color: cfg.primaryColor.withValues(alpha: 0.2),
                          ),
                          label: Text(
                            cfg.collegeName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cfg.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Continue As Last Known User Card
                      if (hasLastUser && !_showNewAccountForm) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cfg.primaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cfg.primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: cfg.primaryColor.withValues(alpha: 0.2),
                                child: ClipOval(
                                  child: lastUser.avatarUrl.isNotEmpty
                                      ? AppImage(
                                          source: lastUser.avatarUrl,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(Icons.person, size: 36, color: cfg.primaryColor),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                lastUser.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lastUser.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    backgroundColor: cfg.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : () => _handleLogin(
                                            name: lastUser.name,
                                            email: lastUser.email,
                                            mobile: lastUser.mobileNumber,
                                          ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Continue as ${lastUser.name.split(' ').first}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () => setState(() => _showNewAccountForm = true),
                          child: Text(
                            'Log in with another account',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cfg.primaryColor,
                            ),
                          ),
                        ),
                      ] else ...[
                        // Full Login Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Student & Staff Login',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Enter your name, email, and phone number to continue.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              // Input: Full Name
                              TextFormField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'e.g. Aarav Sharma',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Enter your full name' : null,
                              ),
                              const SizedBox(height: 16),

                              // Input: Email (College or G-mail)
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'e.g. name@gmail.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter your email address';
                                  if (!v.contains('@') || !v.contains('.')) {
                                    return 'Enter a valid email (e.g. name@gmail.com)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Input: Mobile / Phone Number
                              TextFormField(
                                controller: mobileController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Phone / Mobile Number',
                                  hintText: 'e.g. +91 98765 12345',
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Enter your phone number' : null,
                              ),
                              const SizedBox(height: 24),

                              // Submit Login Button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: cfg.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading ? null : () => _handleLogin(),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Log In to Campus',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),

                              if (hasLastUser) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => setState(() => _showNewAccountForm = false),
                                  child: const Text('Back to Continue as...'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Secure Single-Device Active Session',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
      ),
    );
  }
}
