import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String _selectedRole = 'student';

  Future<void> _handleSignUp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _studentIdController.text.isEmpty ||
        _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        studentId: _studentIdController.text,
        name: _nameController.text,
        role: _selectedRole,
      );

      if (result['success']) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/WhatsApp Image 2025-03-10 at 20.48.39_ce574561.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Sign Up",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: _nameController,
                    hint: "Full Name",
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    hint: "Email",
                    icon: Icons.email,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _studentIdController,
                    hint: "Student/Doctor ID",
                    icon: Icons.badge,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    hint: "Password",
                    icon: Icons.lock,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),
                  _buildRoleSelector(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "SIGN UP",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Already have an account? Login",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: _selectedRole,
        dropdownColor: Colors.blue[700],
        style: const TextStyle(color: Colors.white),
        isExpanded: true,
        underline: Container(),
        items: const [
          DropdownMenuItem(
            value: 'student',
            child: Text('Student'),
          ),
          DropdownMenuItem(
            value: 'doctor',
            child: Text('Doctor'),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _selectedRole = value!;
          });
        },
      ),
    );
  }
}
