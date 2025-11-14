// lib/presentation/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/local_user_service.dart';
import '../../router/app_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _currentUsername = 'Misafir';
  final _localUserService = LocalUserService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = await _localUserService.getSelectedUserId();
    setState(() {
      _currentUsername = userId == LocalUserService.defaultUserId ? 'Misafir' : userId;
      _isLoading = false;
    });
  }
  
  void _logoutAndRedirect() async {
    // Onay dialogu
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oturumu Kapat'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _localUserService.logoutUser();
      if (mounted) {
        context.go(AppRoutes.auth);
      }
    }
  }
  
  // Profil Değiştirme Menüsünü gösterir
  Future<void> _showProfileSelectionMenu() async {
    final allUsernames = await _localUserService.getAllRegisteredUsernames();

    final switchableUsers = allUsernames
        .where((name) => name != _currentUsername && name != LocalUserService.defaultUserId)
        .toList();
    
    if (!mounted) return;

    if (switchableUsers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Başka kayıtlı profil bulunamadı. Yeni profil oluşturun.')),
        );
        return; 
    }
    
    final selectedUsername = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Profil Seç", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
              ),
            ),
            ...switchableUsers.map((username) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(username),
                onTap: () {
                  Navigator.pop(context, username);
                },
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        );
      },
    );

    // Kullanıcı seçildiyse
    if (selectedUsername != null && selectedUsername != _currentUsername) {
        await _localUserService.setSelectedUserId(selectedUsername);
        
        // Ana Sayfaya yönlendir (HomeScreen otomatik yenilenecek)
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$selectedUsername profiline geçildi!')),
            );
            context.go(AppRoutes.home); 
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String initialLetter = _currentUsername.isNotEmpty 
        ? _currentUsername[0].toUpperCase() 
        : 'M';
        
    final bool isGuest = _currentUsername == 'Misafir';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilim"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- PROFİL AVATARI VE DEĞİŞTİRME BUTONU ---
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Ana Avatar
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      initialLetter,
                      style: const TextStyle(
                        fontSize: 50, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white
                      ),
                    ),
                  ),
                  
                  // Değiştirme Butonu (Sağ alt köşede)
                  if (!isGuest)
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showProfileSelectionMenu,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.swap_horiz,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Kullanıcı Adı
              Text(
                _currentUsername,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 10),
              
              // Durum Bilgisi
              Text(
                isGuest ? 'Lütfen giriş yapın veya kayıt olun.' : 'Aktif profiliniz.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              
              const SizedBox(height: 40),
              
              // --- BUTONLAR ---
              // Misafirse Giriş/Kayıt butonu
              if (isGuest)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.auth),
                    icon: const Icon(Icons.login),
                    label: const Text('Giriş Yap / Kayıt Ol'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              // Giriş yapmışsa Çıkış butonu
              if (!isGuest)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: _logoutAndRedirect,
                    icon: const Icon(Icons.logout),
                    label: const Text('Oturumu Kapat'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Yeni Profil Oluşturma Butonu (Tüm kullanıcılar için)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.auth),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Yeni Profil Oluştur'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    foregroundColor: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}