// lib/presentation/auth/login_register_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/local_user_service.dart';
import '../../router/app_router.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> with SingleTickerProviderStateMixin {
  final LocalUserService _userService = LocalUserService();
  
  late TabController _tabController;
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleAuth(bool isLogin) async {
    setState(() => _errorMessage = null);
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim(); // Şifre boşlukları temizlendi

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Kullanıcı adı ve şifre boş bırakılamaz.");
      return;
    }

    bool success;
    if (isLogin) {
      success = await _userService.loginUser(username, password);
    } else {
      success = await _userService.registerUser(username, password);
    }

    if (success) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(AppRoutes.home);
        });
      }
    } else {
      setState(() {
        _errorMessage = isLogin 
            ? "Hata: Kullanıcı adı veya şifre yanlış." 
            : "Hata: Bu kullanıcı adı zaten kayıtlı.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hesap Oluştur / Giriş Yap"),
        automaticallyImplyLeading: true, 
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Giriş Yap"),
            Tab(text: "Kayıt Ol"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAuthForm(isLogin: true),
          _buildAuthForm(isLogin: false),
        ],
      ),
    );
  }

  Widget _buildAuthForm({required bool isLogin}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: "Kullanıcı Adı (Çocuk Adı)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Şifre",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 24),
          
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            
          ElevatedButton(
            onPressed: () => _handleAuth(isLogin),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: isLogin ? Colors.green : Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(
              isLogin ? "Giriş Yap" : "Kayıt Ol",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          
          const SizedBox(height: 10),
          Text(
            isLogin ? "Kayıtlı değilsen 'Kayıt Ol' sekmesini kullan." : "Minimum 4 karakterli, sadece harf veya rakam kullanın.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}