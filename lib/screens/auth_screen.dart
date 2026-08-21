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

  /// Null = account needs no password on this device. Set/enter = the
  /// password section is shown instead of the 3-field login form.
  PasswordMode? _passwordMode;
  String _passwordError = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  /// Account details from the "Continue as..." card while its password is
  /// being verified. The 3-field form controllers stay empty during that flow,
  /// so the password submit must use these instead.
  String? _pendingName;
  String? _pendingEmail;
  String? _pendingMobile;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({String? name, String? email, String? mobile}) async {
    final loginName = name ?? nameController.text.trim();
    final loginEmail = email ?? emailController.text.trim();
    final loginMobile = mobile ?? mobileController.text.trim();

    if (name == null && !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _passwordError = '';
    });

    final dataService = Provider.of<MockDataService>(context, listen: false);

    try {
      await dataService.loginUser(
        name: loginName,
        email: loginEmail,
        mobileNumber: loginMobile,
        continueAs: name != null,
      );
      if (mounted) {
        widget.onLoginComplete();
      }
    } on PasswordRequiredException catch (e) {
      if (mounted) {
        setState(() {
          _passwordMode = e.mode;
          _passwordError = '';
          passwordController.clear();
          confirmPasswordController.clear();
          // Continue-as card flow: the form controllers are empty, remember
          // the account so the password submit targets the right identity.
          _pendingName = name == null ? loginName : null;
          _pendingEmail = name == null ? loginEmail : null;
          _pendingMobile = name == null ? loginMobile : null;
        });
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

  Future<void> _handlePasswordSubmit() async {
    final password = passwordController.text;
    if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters.');
      return;
    }
    if (_passwordMode == PasswordMode.set &&
        password != confirmPasswordController.text) {
      setState(() => _passwordError = 'Passwords do not match.');
      return;
    }
    setState(() {
      _isLoading = true;
      _passwordError = '';
    });

    final dataService = Provider.of<MockDataService>(context, listen: false);
    // Prefer the pending continue-as account; fall back to the form fields.
    final name = _pendingName ?? nameController.text.trim();
    final email = _pendingEmail ?? emailController.text.trim();
    final mobile = _pendingMobile ?? mobileController.text.trim();

    try {
      if (_passwordMode == PasswordMode.set) {
        await dataService.setPasswordForLogin(
          name: name,
          email: email,
          mobileNumber: mobile,
          password: password,
        );
      } else {
        await dataService.loginWithPassword(
          name: name,
          email: email,
          mobileNumber: mobile,
          password: password,
        );
      }
      if (mounted) {
        widget.onLoginComplete();
      }
    } on PasswordRequiredException catch (e) {
      if (mounted) {
        setState(() {
          _passwordMode = e.mode;
          _passwordError = '';
          passwordController.clear();
          confirmPasswordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _passwordError = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final effectiveEmail = (_pendingEmail ?? emailController.text).trim();
    final emailInputCtrl = TextEditingController(text: effectiveEmail);
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    final dataService = Provider.of<MockDataService>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool obscureNew = true;
    bool obscureConfirm = true;
    String errorText = '';
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? const Color(0xFF27272A) : Colors.grey.shade200,
              ),
            ),
            title: Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (effectiveEmail.isNotEmpty) ...[
                    Text(
                      'Account: $effectiveEmail',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0038D8),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: emailInputCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Your Registered Email',
                        labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600),
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF3F3F46) : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'New Password (min 6 chars)',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600),
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                        ),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF3F3F46) : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600),
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                        ),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF3F3F46) : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorText,
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isResetting ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isResetting
                    ? null
                    : () async {
                        final emailToUse = emailInputCtrl.text.trim();
                        if (emailToUse.isEmpty) {
                          setDialogState(() => errorText = 'Enter your account email.');
                          return;
                        }
                        final newPassword = newPasswordController.text;
                        if (newPassword.length < 6) {
                          setDialogState(() => errorText = 'Password must be at least 6 characters.');
                          return;
                        }
                        if (newPassword != confirmController.text) {
                          setDialogState(() => errorText = 'Passwords do not match.');
                          return;
                        }

                        setDialogState(() {
                          isResetting = true;
                          errorText = '';
                        });

                        try {
                          await dataService.resetPassword(
                            email: emailToUse,
                            password: newPassword,
                          );
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          if (mounted) {
                            setState(() {
                              _passwordError = '';
                              passwordController.clear();
                              confirmPasswordController.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✅ Password reset! Enter your new password to continue.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            setDialogState(() {
                              isResetting = false;
                              errorText = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        }
                      },
                child: isResetting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Reset Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final cfg = dataService.config;
    // The seed/demo identity (usr_101) is never a real account and must not
    // be offered as a continue-as option. Same for anything restored from an
    // old snapshot that isn't a genuine onboarding-completed user.
    final storedLast = dataService.lastKnownUser;
    final sessionCandidate = (!dataService.isLoggedOut &&
            dataService.currentUser.id.isNotEmpty &&
            dataService.currentUser.id != 'usr_101')
        ? dataService.currentUser
        : null;
    final lastUser = (storedLast != null && storedLast.id != 'usr_101'
            ? storedLast
            : null) ??
        sessionCandidate;
    final hasLastUser = lastUser != null && lastUser.email.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: isDark ? const Color(0xFF141414) : Colors.white,
                elevation: isDark ? 0 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Header (Text & Icon badge)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cfg.primaryColor.withValues(alpha: isDark ? 0.18 : 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            size: 36,
                            color: cfg.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 30,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Student',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: 'Hub',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0038D8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Digital Campus Platform',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Continue As Last Known User Card
                      if (hasLastUser && !_showNewAccountForm) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : cfg.primaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF333333) : cfg.primaryColor.withValues(alpha: 0.25),
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
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lastUser.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFA1A1AA) : Colors.grey,
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
                              color: isDark ? const Color(0xFF60A5FA) : cfg.primaryColor,
                            ),
                          ),
                        ),
                      ] else if (_passwordMode != null) ...[
                        _buildPasswordSection(),
                      ] else ...[
                        // Full Login Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Student & Staff Login',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enter your details to access campus services.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 22),

                              // Input: Full Name
                              TextFormField(
                                controller: nameController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600),
                                  hintText: 'e.g. Aarav Sharma',
                                  hintStyle: TextStyle(color: isDark ? const Color(0xFF71717A) : Colors.grey.shade400),
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                                ),
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Enter your full name' : null,
                              ),
                              const SizedBox(height: 16),

                              // Input: Email (College or G-mail)
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600),
                                  hintText: 'e.g. name@gmail.com',
                                  hintStyle: TextStyle(color: isDark ? const Color(0xFF71717A) : Colors.grey.shade400),
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
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
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  labelText: 'Phone / Mobile Number',
                                  labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600),
                                  hintText: 'e.g. +91 98765 12345',
                                  hintStyle: TextStyle(color: isDark ? const Color(0xFF71717A) : Colors.grey.shade400),
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
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
                                  child: Text(
                                    'Back to Continue as...',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFFA1A1AA) : null,
                                    ),
                                  ),
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
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: isDark ? const Color(0xFF71717A) : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Secure Single-Device Active Session',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF71717A) : Colors.grey,
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
      ),
    );
  }

  Widget _buildPasswordSection() {
    final cfg = Provider.of<MockDataService>(context).config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSetMode = _passwordMode == PasswordMode.set;
    final accountName = (_pendingName ?? nameController.text).trim();
    final accountEmail = (_pendingEmail ?? emailController.text).trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : cfg.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : cfg.primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_rounded, size: 38, color: cfg.primaryColor),
          const SizedBox(height: 12),
          Text(
            isSetMode ? 'Set a Password' : 'Enter Your Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSetMode
                ? 'Choose a password to secure this account. It will only be asked when logging in from a new device.'
                : 'This account is password protected. Verify it\u2019s you to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFA1A1AA) : Colors.grey,
            ),
          ),
          if (accountEmail.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '$accountName${accountName.isNotEmpty ? ' • ' : ''}$accountEmail',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF60A5FA) : cfg.primaryColor,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: isSetMode ? 'Password (min 6 characters)' : 'Password',
              labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF27272A) : Colors.white,
            ),
          ),
          if (isSetMode) ...[
            const SizedBox(height: 14),
            TextField(
              controller: confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                  ),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF27272A) : Colors.white,
              ),
            ),
          ],
          if (_passwordError.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ $_passwordError',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ],
          const SizedBox(height: 18),
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
            onPressed: _isLoading ? null : _handlePasswordSubmit,
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
                    isSetMode ? 'Set Password & Continue' : 'Log In Securely',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          if (!isSetMode) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showForgotPasswordDialog,
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF60A5FA) : cfg.primaryColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() {
              _passwordMode = null;
              _passwordError = '';
              passwordController.clear();
              confirmPasswordController.clear();
              _pendingName = null;
              _pendingEmail = null;
              _pendingMobile = null;
            }),
            child: Text(
              'Use a different account',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
