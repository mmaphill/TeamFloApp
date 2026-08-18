import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true; // Toggle between logging in and signup
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? error = await _authService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      print('Login Successful!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        // TODO: Navigate to Homescreen
      }
    } else {
      setState(() =>_errorMessage = error);
    }
  }

  Future<void> _handleSignup() async {
    if (_nameController.text.isEmpty) {
      setState(() => _errorMessage = 'Name is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? error = await _authService.signup(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text,
      role: 'member', // New users are members by default
    );

    setState(() => _isLoading = false);

    if (error == null) {
      setState(() => _errorMessage = 'Account created! Please log in.');
      _switchToLogin();
    } else {
      setState(() => _errorMessage = error);
    }
  }

  void _switchToLogin() {
    setState(() {
      _isLogin = true;
      _nameController.clear();
      _errorMessage = null;
    });
  }

  void _switchToSignup() {
    setState(() {
      _isLogin = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TeamFloApp')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              _isLogin ? 'Welcome Back' : 'Create Account',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLogin
                ? 'Login to your account' : 'Sign up to get started',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Error Message
            if (_errorMessage != null) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration( color: Colors.red.shade100, borderRadius: BorderRadius.circular(8),), child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700),),),
            if (_errorMessage != null) const SizedBox(height: 16),

            // Name field (signup only)
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Email field
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Password Field
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Login/Signup button
            ElevatedButton(
              onPressed: _isLoading ? null : (_isLogin ? _handleLogin : _handleSignup),
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2),) : Text(_isLogin ? 'Login' : 'Sign Up'),
            ),
            const SizedBox(height: 16),

            // Toggle between login and signup
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin ? "Don't have an account? " : 'Already have an account? ',
                ),
                GestureDetector(
                  onTap: _isLogin ? _switchToSignup : _switchToLogin,
                  child: Text(
                    _isLogin ? 'Sign Up' : 'Login',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}