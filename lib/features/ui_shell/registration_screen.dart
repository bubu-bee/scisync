import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../firestore_data/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  final void Function()? onTap;
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

  // --- Campus ID Verification States ---
  bool _isIdVerified = false;
  String _verifiedNic = '';
  bool _isHandlingScan = false;

  // --- NATIVE DATE OF BIRTH PICKER ---
  Future<void> _selectDob(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2003), // Default reasonable age for undergraduates
      firstDate: DateTime(1990),
      lastDate: DateTime(2010),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _dobController.text =
            "${pickedDate.year.toString().padLeft(4, '0')}-"
            "${pickedDate.month.toString().padLeft(2, '0')}-"
            "${pickedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // --- Barcode Scanner Dialog Logic ---
  void _openIdScanner() {
    String enteredNic = _nicController.text.trim();

    if (enteredNic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your NIC number first!')),
      );
      return;
    }

    _isHandlingScan = false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Scan CVC Campus ID Barcode'),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              if (_isHandlingScan) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? scannedValue = barcode.rawValue;

                if (scannedValue != null) {
                  String cleanScanned = scannedValue.trim();

                  if (cleanScanned == enteredNic) {
                    _isHandlingScan = true;
                    Navigator.pop(context);

                    setState(() {
                      _isIdVerified = true;
                      _verifiedNic = enteredNic;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Campus ID successfully verified with NIC!',
                        ),
                        backgroundColor: Colors.teal,
                      ),
                    );
                    return;
                  } else {
                    _isHandlingScan = true;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'ID Mismatch! Scanned ($cleanScanned) does not match entered NIC ($enteredNic).',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }
              }
            },
          ),
        ),
      ),
    );
  }

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

    if (!_isIdVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must scan and verify your CVC Campus ID before registering.',
          ),
          backgroundColor: Colors.red,
        ),
      );
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

              // --- NIC TEXT FIELD WITH LIVE VERIFICATION RESET WATCHER ---
              TextField(
                controller: _nicController,
                decoration: InputDecoration(
                  labelText: 'National Identity Card (NIC)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.credit_card),
                  suffixIcon: _isIdVerified
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
                onChanged: (val) {
                  if (_isIdVerified && val.trim() != _verifiedNic) {
                    setState(() => _isIdVerified = false);
                  }
                },
              ),
              const SizedBox(height: 12),

              // --- SCAN CAMPUS ID BUTTON ---
              OutlinedButton.icon(
                onPressed: _openIdScanner,
                icon: Icon(
                  _isIdVerified ? Icons.verified : Icons.qr_code_scanner,
                  color: _isIdVerified ? Colors.green : Colors.teal,
                ),
                label: Text(
                  _isIdVerified
                      ? "Campus ID Verified"
                      : "Scan CVC Campus ID Barcode",
                  style: TextStyle(
                    color: _isIdVerified ? Colors.green : Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _isIdVerified ? Colors.green : Colors.teal,
                    width: 1.5,
                  ),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- DOB TEXT FIELD WITH NATIVE DATE PICKER ---
              TextField(
                controller: _dobController,
                readOnly: true, // Prevents manual typing errors
                onTap: () => _selectDob(context), // Opens calendar popup
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today, color: Colors.teal),
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
                initialValue: _selectedBatch,
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

              // --- SECURED SIGN UP BUTTON ---
              ElevatedButton(
                onPressed: (_isLoading || !_isIdVerified)
                    ? null
                    : _handleSignUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.teal,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isIdVerified
                            ? 'Sign Up'
                            : 'Scan ID to Enable Registration',
                        style: TextStyle(
                          fontSize: 16,
                          color: _isIdVerified
                              ? Colors.white
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

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
