// lib/presentation/auth/profile_verification_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/local_user_service.dart';
import '../../router/app_router.dart';

class ProfileVerificationScreen extends StatefulWidget {
  const ProfileVerificationScreen({super.key});

  @override
  State<ProfileVerificationScreen> createState() => _ProfileVerificationScreenState();
}

class _ProfileVerificationScreenState extends State<ProfileVerificationScreen> {
  final LocalUserService _userService = LocalUserService();
  List<String> _availableUsernames = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadUsernames();
  }
  
  Future<void> _loadUsernames() async {
    final usernames = await _userService.getAllRegisteredUsernames();
    setState(() {
      _availableUsernames = usernames;
      _isLoading = false;
    });
  }
  
  // Şifre doğrulama dialogunu açar ve giriş yapmayı dener
  Future<void> _verifySelectedProfile(String username) async {
      final TextEditingController passwordController = TextEditingController();
      bool loginSuccess = false;

      final bool? verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // İlk açılışta kapatılamaz
        builder: (context) => PopScope(
            canPop: false, // Geri tuşunu devre dışı bırak
            child: AlertDialog(
            title: Text('Giriş Yap: $username'),
            content: TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Şifre'),
                onSubmitted: (value) => Navigator.of(context).pop(true),
            ),
            actions: [
                // İptal butonu sadece başka bir profile geçiş için gereklidir.
                // İlk açılışta iptal butonu yerine Yeni Profil Oluştur butonu alt kısımda var.
                ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Doğrula')),
            ],
            ),
        ),
      );

      if (verified == true) {
        final password = passwordController.text.trim(); 
        loginSuccess = await _userService.loginUser(username, password);
        
        if (loginSuccess) {
             // Başarılı giriş: ID'yi seçili olarak kaydet ve Home'a git.
             await _userService.setSelectedUserId(username);
             if (mounted) context.go(AppRoutes.home);
        } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hata: Şifre yanlış.')),
            );
            // Şifre yanlışsa dialogu tekrar açar.
            _verifySelectedProfile(username);
        }
      }
      passwordController.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator())); 
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Seçimi'),
        automaticallyImplyLeading: false, // Geri tuşunu kaldır
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Lütfen giriş yapmak istediğiniz profili seçin:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _availableUsernames.length,
              itemBuilder: (context, index) {
                final username = _availableUsernames[index];
                final initialLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text(initialLetter, style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(username),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => _verifySelectedProfile(username),
                );
              },
            ),
          ),
          // Yeni Profil Oluşturma Butonu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.auth), 
                icon: const Icon(Icons.person_add),
                label: const Text('Yeni Profil Oluştur'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          )
        ],
      ),
    );
  }
}