import 'package:flutter/material.dart';
import 'package:wefarm/login_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isChecked = false;
  bool _isLoading = false;
  final _focusNodeEmail = FocusNode();
  final _focusNodePhone = FocusNode();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void dispose() {
    _focusNodeEmail.dispose();
    _focusNodePhone.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    setState(() => _isLoading = true);

    try {
      // Input validation
      if (_usernameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _phoneController.text.isEmpty ||
          _addressController.text.isEmpty ||
          _passwordController.text.isEmpty) {
        throw Exception("Semua field harus diisi!");
      }

      if (!isEmailValid(_emailController.text.trim())) {
        throw Exception("Email tidak valid!");
      }

      if (!isPasswordValid(_passwordController.text)) {
        throw Exception("Password minimal 6 karakter!");
      }

      if (!_isChecked) {
        throw Exception("Anda harus menyetujui Syarat & Ketentuan!");
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        throw Exception("Password tidak sama!");
      }

      // Send registration data to the server
      final response = await http.post(
        Uri.parse(
            "http://192.168.56.1/wefarm/lib/register.php"), // Replace with your actual server URL
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _usernameController.text.trim(),
          "email": _emailController.text.trim(),
          "phone": _phoneController.text.trim(),
          "address": _addressController.text.trim(),
          "password": _passwordController.text.trim(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            "Koneksi server gagal. Status code: ${response.statusCode}");
      }

      final responseData = jsonDecode(response.body);
      if (!responseData["success"]) {
        throw Exception(responseData["message"]);
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registrasi berhasil! Silahkan login."),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to login screen after successful registration
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool isPasswordValid(String password) {
    return password.length >= 6;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo dan Teks "Sign Up"
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Logo
                  Image.asset(
                    'assets/logo_wefarm.png',
                    width: 125,
                    height: 125,
                  ),
                  const SizedBox(width: 8.0),
                  // Teks "Sign Up"
                  const Text(
                    "Sign Up",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28.0),

              // Registration Form Container
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 16.0),
                  child: Column(
                    children: [
                      // Input Username
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 8.0),
                        ),
                      ),
                      Divider(color: Colors.grey.withOpacity(0.5)),

                      // Input Email
                      TextField(
                        controller: _emailController,
                        focusNode: _focusNodeEmail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context)
                            .requestFocus(_focusNodePhone),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 8.0),
                        ),
                      ),
                      Divider(color: Colors.grey.withOpacity(0.5)),

                      // Input Phone Number
                      TextField(
                        controller: _phoneController,
                        focusNode: _focusNodePhone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 8.0),
                        ),
                      ),
                      Divider(color: Colors.grey.withOpacity(0.5)),

                      // Input Address
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 8.0),
                        ),
                      ),
                      Divider(color: Colors.grey.withOpacity(0.5)),

                      // Input Password
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 8.0),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      Divider(color: Colors.grey.withOpacity(0.5)),

                      // Input Confirm Password
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_isConfirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 8.0),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // Terms & Conditions Checkbox
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _isChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        _isChecked = value ?? false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      "I agree to the Terms & Conditions and Privacy Policy",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf5bd52),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        )
                      : const Text(
                          "Sign Up",
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
              const SizedBox(height: 16.0),

              // Social Sign Up Options
              const Text(
                "Or sign up with",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google Sign Up
                  IconButton(
                    onPressed: () {
                      // Implement Google sign up
                    },
                    icon: Image.asset(
                      'assets/google_logo.png',
                      width: 30,
                      height: 30,
                    ),
                  ),
                  const SizedBox(width: 8.0),

                  // Facebook Sign Up
                  IconButton(
                    onPressed: () {
                      // Implement Facebook sign up
                    },
                    icon: Image.asset(
                      'assets/facebook_logo.png',
                      width: 30,
                      height: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),

              // Login Link
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
