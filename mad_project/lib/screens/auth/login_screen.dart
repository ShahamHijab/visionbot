import 'package:flutter/material.dart';
import 'signup_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 25),

              Image.asset("assets/logobg.png", width: 95),

              const SizedBox(height: 12),

              const Text(
                "Welcome Back!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 3),

              const Text(
                "Sign in to access your surveillance dashboard",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 28),

              // Email
              _inputField(
                label: "Email Address",
                hint: "your.email@example.com",
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 16),

              // Password
              _inputField(
                label: "Password",
                hint: "Enter Your Password",
                icon: Icons.lock_outline,
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Checkbox(value: false, onChanged: (v) {}),
                  const Text("Remember Me"),
                ],
              ),

              const SizedBox(height: 10),

              // Sign in button
              _gradientButton(
                text: "Sign In",
                onTap: () {},
              ),

              const SizedBox(height: 24),

              Row(
                children: const [
                  Expanded(child: Divider(thickness: 1, color: Colors.black12)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("or continue with"),
                  ),
                  Expanded(child: Divider(thickness: 1, color: Colors.black12)),
                ],
              ),

              const SizedBox(height: 14),

              // Google button
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Image.network(
                  "https://upload.wikimedia.org/wikipedia/commons/0/09/IOS_Google_icon.png",
                  width: 32,
                ),
              ),

              const SizedBox(height: 25),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SignupScreen()));
                },
                child: const Text.rich(
                  TextSpan(
                    text: "Don’t have an account? ",
                    style: TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: "Sign Up",
                        style: TextStyle(color: Colors.blue),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(
      {required String label,
      required String hint,
      required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.purple.shade300, width: 1.4),
          ),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.black54),
              hintText: hint,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientButton({required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFB800FF),
              Color(0xFF7EE8FA),
            ],
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
