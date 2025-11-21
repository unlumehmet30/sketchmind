// lib/presentation/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../data/services/local_user_service.dart';
import '../../router/app_router.dart';
import '../../data/dummy/avatars.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _currentUsername = 'Misafir';
  String? _currentAvatarUrl;
  final _localUserService = LocalUserService();
  
  bool _isParentMode = false;
  bool _isLoading = true;

  // Renk tanımlamaları (Kullanıcının isteği: Pastel Mor/Pembe karışımı ve Yeşil)
  static const Color _childModeColor = Color.fromARGB(255, 161, 125, 196); // Pastel Mor
  static const Color _parentModeColor = Color.fromARGB(255, 29, 221, 35); // Yeşil

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
    final parentMode = await _localUserService.getIsParentMode();

    if(mounted) {
      setState(() {
        _currentUsername = userId == LocalUserService.defaultUserId ? 'Misafir' : userId;
        _currentAvatarUrl = avatarUrl;
        _isParentMode = parentMode;
        _isLoading = false;
      });
    }
  }
  
  void _logoutAndRedirect() async {
    await _localUserService.logoutUser();
    if (mounted) context.go(AppRoutes.auth);
  }

  // Ebeveyn Modunu Değiştirme (Şifre Sorar)
  void _toggleParentMode(bool requestedValue) async {
    // 1. Misafir kullanıcı ise engelle
    if (_currentUsername == 'Misafir') {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giriş yapmadan ayarları değiştiremezsiniz.')));
        return;
    }
    
    // 2. Şifre Doğrulama Dialogunu aç
    final success = await _showPasswordDialog();
    
    if (success == true) {
      // 3. BAŞARILI: Veri kaydet ve UI güncelle
      await _localUserService.setIsParentMode(requestedValue);
      if(mounted) {
        setState(() => _isParentMode = requestedValue);
        // Home ekranını güncellemek için yönlendirme yap
        context.go(AppRoutes.home);
      }
    } 
    // 4. BAŞARISIZ: Hiçbir şey yapma. _isParentMode zaten eski değerinde kaldı.
  }

  // GÜVENİLİR ŞİFRE DOĞRULAMA DİYALOĞU
  Future<bool> _showPasswordDialog() async {
    final controller = TextEditingController();
    
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String error = '';
            
            void verify() async {
              if (!dialogContext.mounted) return;
              
              // Şifre kontrolü
              final success = await _localUserService.loginUser(_currentUsername, controller.text.trim());
              
              if (!dialogContext.mounted) return;

              if (success) {
                Navigator.pop(dialogContext, true); // Başarılı, true döndür
              } else {
                setDialogState(() => error = 'Yanlış şifre'); // Hata mesajını dialog içinde göster
              }
            }
            
            return AlertDialog(
              title: const Text('Ebeveyn Doğrulaması'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Modu değiştirmek için şifrenizi girin: (${_currentUsername})"),
                    TextField(
                        controller: controller, 
                        obscureText: true, 
                        decoration: InputDecoration(labelText: 'Şifre', errorText: error.isEmpty ? null : error),
                        onSubmitted: (_) => verify(), 
                    ),
                  ],
                ),
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
                  ElevatedButton(
                      onPressed: verify, 
                      child: const Text('Doğrula')
                  ),
              ],
            );
          }
        );
      },
    );
    return result ?? false;
  }
  
  void _showAvatarSelectionMenu() {
    if (_currentUsername == 'Misafir') return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: true,
          builder: (context, scrollController) {
            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: DefaultTabController(
                length: predefinedAvatars.length,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 10),
                    const Text("Yeni Avatarını Seç", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                onTap: () async {
                                  await _localUserService.setSelectedUserAvatar(_currentUsername, url);
                                  if (mounted) {
                                    setState(() {
                                      _currentAvatarUrl = url;
                                    });
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar güncellendi!')));
                                  }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final bool isGuest = _currentUsername == 'Misafir';
    final String initialLetter = _currentUsername.isNotEmpty ? _currentUsername[0].toUpperCase() : 'M';

    final Color toggleBgColor = _isParentMode ? _parentModeColor : _childModeColor;

    final Widget avatarWidget = CircleAvatar(
        radius: 60,
        backgroundColor: Colors.blueAccent,
        backgroundImage: _currentAvatarUrl != null && !isGuest
            ? CachedNetworkImageProvider(_currentAvatarUrl!) as ImageProvider
            : null,
        child: _currentAvatarUrl == null || isGuest
            ? Text(initialLetter, style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white)) 
            : null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Profilim")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              
              // --- EBEVEYN MODU TOGGLE (Yuvarlak, Üst Ortada) ---
              if (!isGuest)
              Center(
                child: GestureDetector(
                  onTap: () => _toggleParentMode(!_isParentMode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 150,
                    height: 50,
                    decoration: BoxDecoration(
                      color: toggleBgColor.withOpacity(0.9), // Hafif pastel görünüm
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: toggleBgColor, width: 2)
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Stack(
                      children: [
                        // Arka plan simgeleri (soluk)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(Icons.child_care, color: Colors.white54, size: 30),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Icon(Icons.supervisor_account, color: Colors.white54, size: 30),
                        ),
                        // HAREKET EDEN YUVALAK GÖSTERGE (Mevcut Modun İkonu)
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          alignment: _isParentMode ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Icon(
                              _isParentMode ? Icons.lock_open : Icons.lock, 
                              color: _isParentMode ? _parentModeColor : _childModeColor
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // --- PROFİL AVATARI ---
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        avatarWidget,
                        // Avatar Değiştirme Butonu
                        if (!isGuest)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showAvatarSelectionMenu,
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
                    
                    const SizedBox(height: 20),
                    Text(_currentUsername, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(isGuest ? 'Lütfen giriş yapın.' : 'Aktif profiliniz.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    
                    const SizedBox(height: 50),

                    // --- ALT BUTONLAR ---
                    SizedBox(
                      width: double.infinity,
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
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go(AppRoutes.auth),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Yeni Profil Oluştur'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          foregroundColor: Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}