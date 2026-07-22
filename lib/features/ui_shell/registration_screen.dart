import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firestore_data/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  final void Function()? onTap; // <-- NEW: Accept the toggle switch
  const RegistrationScreen({super.key, required this.onTap});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nicController = TextEditingController();
  final _dobController = TextEditingController();
  final _badgeController = TextEditingController();

  String _selectedBatch = '23com';
  final List<String> _batchOptions = ['22com', '23com', '24com'];
  bool _isLoading = false;
  final _badgeRegex = RegExp(r'^\d{2}[a-zA-Z]{3}\d{1,4}$');

  Future<void> _handleSignUp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _nicController.text.isEmpty ||
        _dobController.text.isEmpty ||
        _badgeController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (!_badgeRegex.hasMatch(_badgeController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Badge Format. Example: 23com234'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService().signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        batch: _selectedBatch,
        badgeNumber: _badgeController.text.trim(),
        nic: _nicController.text.trim(),
        dob: _dobController.text.trim(),
      );
      // AuthWrapper automatically handles the screen change here!
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Registration failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nicController.dispose();
    _dobController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join SciSync')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create your student account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _badgeController,
                decoration: const InputDecoration(
                  labelText: 'Badge Number (e.g. 23com234)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nicController,
                decoration: const InputDecoration(
                  labelText: 'National Identity Card (NIC)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'University Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedBatch,
                decoration: const InputDecoration(
                  labelText: 'Academic Batch',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                items: _batchOptions
                    .map(
                      (batch) =>
                          DropdownMenuItem(value: batch, child: Text(batch)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBatch = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.teal,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Sign Up',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
              const SizedBox(height: 16),

              // <-- NEW: Using the toggle switch instead of Navigator! -->
              TextButton(
                onPressed: widget.onTap,
                child: const Text(
                  "Already have an account? Log In",
                  style: TextStyle(color: Colors.teal, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
