// lib/presentation/auth/login_register_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/local_user_service.dart';
import '../../router/app_router.dart';
import '../../data/dummy/avatars.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  String? _selectedAvatarUrl; // Seçilen avatar URL'i

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
    
    // KRİTİK: Kullanıcı adı ve şifreyi temizle (trim)
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim(); 

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Kullanıcı adı ve şifre boş bırakılamaz.");
      return;
    }

    bool success;
    if (isLogin) {
      // HATA VEREN ÇAĞRI: Şimdi LocalUserService'te tanımlı
      success = await _userService.loginUser(username, password); 
    } else {
      success = await _userService.registerUser(username, password, avatarUrl: _selectedAvatarUrl);
    }

    if (success) {
      if (mounted) {
        // Güvenli yönlendirme
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
    // ... (Form Widget'ının geri kalanı aynı) ...
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isLogin) ...[
             Center(
               child: GestureDetector(
                 onTap: _showAvatarSelectionDialog,
                 child: CircleAvatar(
                   radius: 40,
                   backgroundColor: Colors.grey.shade200,
                   backgroundImage: _selectedAvatarUrl != null 
                       ? CachedNetworkImageProvider(_selectedAvatarUrl!) 
                       : null,
                   child: _selectedAvatarUrl == null 
                       ? const Icon(Icons.add_a_photo, size: 30, color: Colors.grey)
                       : null,
                 ),
               ),
             ),
             const SizedBox(height: 8),
             const Text("Avatar Seç", textAlign: TextAlign.center, style: TextStyle(color: Colors.blue)),
             const SizedBox(height: 20),
          ],
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
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showAvatarSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: true, // Fixed: expand true allows Expanded to work
          builder: (context, scrollController) {
            return Material( // Added Material for background
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: DefaultTabController(
                length: predefinedAvatars.length,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 10),
                    const Text("Bir Avatar Seç", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TabBar(
                      isScrollable: true,
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      tabs: predefinedAvatars.map((cat) => Tab(text: cat.name)).toList(),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: predefinedAvatars.map((category) {
                          return GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: category.imageUrls.length,
                            itemBuilder: (context, index) {
                              final url = category.imageUrls[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedAvatarUrl = url);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}