// lib/presentation/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../data/services/local_user_service.dart';
import '../../router/app_router.dart';
import '../../data/dummy/avatars.dart'; // AvatarCategory ve dummy veriler

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _currentUsername = 'Misafir';
  String? _currentAvatarUrl;
  final _localUserService = LocalUserService();
  bool _isLoading = true; // Yükleme durumu eklendi

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = await _localUserService.getSelectedUserId();
    final avatarUrl = userId != LocalUserService.defaultUserId 
        ? await _localUserService.getSelectedUserAvatar(userId) 
        : defaultAvatarUrl; 
        
    setState(() {
      _currentUsername = userId == LocalUserService.defaultUserId ? 'Misafir' : userId;
      _currentAvatarUrl = avatarUrl;
      _isLoading = false; // Yükleme bitti
    });
  }
  
  void _logoutAndRedirect() async {
    // Onay dialogu burada yer alabilir...
    await _localUserService.logoutUser();
    if (mounted) {
      context.go(AppRoutes.auth);
    }
  }

  // Avatar seçim menüsünü gösterir
  Future<void> _showAvatarSelectionMenu() async {
    if (_currentUsername == LocalUserService.defaultUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Misafir kullanıcılar avatar değiştiremez.')),
      );
      return;
    }

    final selectedAvatarUrl = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text("Avatar Seç", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),
                    
                    // Kategoriye Göre Avatar Listesi
                    ...predefinedAvatars.map((category) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Text(category.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4, 
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: category.imageUrls.length,
                            itemBuilder: (context, index) {
                              final url = category.imageUrls[index];
                              final isSelected = _currentAvatarUrl == url;
                              return GestureDetector(
                                onTap: () => Navigator.pop(context, url),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: isSelected ? Border.all(color: Colors.blueAccent, width: 3) : null,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.grey.shade100,
                                    backgroundImage: CachedNetworkImageProvider(url),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // KONTROL: Eğer bir avatar URL'si seçildiyse
    if (selectedAvatarUrl != null && mounted) {
      await _localUserService.setSelectedUserAvatar(_currentUsername, selectedAvatarUrl);
      
      // Avatar URL'sini yerel state'te güncelle
      setState(() {
        _currentAvatarUrl = selectedAvatarUrl;
      });
      
      // Ana Sayfaya yönlendir (HomeScreen'deki didChangeDependencies'i tetikler)
      context.go(AppRoutes.home); 
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ... (Avatar ve Misafir kontrolleri) ...
    
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
              // --- PROFİL AVATARI VE DEĞİŞTİRME ROZETİ ---
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blueAccent,
                    backgroundImage: _currentAvatarUrl != null && !isGuest
                        ? CachedNetworkImageProvider(_currentAvatarUrl!) as ImageProvider
                        : null,
                    child: _currentAvatarUrl == null || isGuest
                        ? Text(
                            initialLetter,
                            style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
                  
                  // Değiştirme Rozeti
                  if (!isGuest)
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showAvatarSelectionMenu, // Avatar seçim menüsünü aç
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              Text(
                _currentUsername,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 40),
              
              // --- ÇIKIŞ YAP BUTONU ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: _logoutAndRedirect,
                  icon: Icon(isGuest ? Icons.login : Icons.logout),
                  label: Text(isGuest ? 'Giriş Yap / Kayıt Ol' : 'Oturumu Kapat'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: isGuest ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Yeni Profil Oluşturma Butonu
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