// lib/presentation/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../data/dummy/stories.dart'; 
import '../../router/app_router.dart';
import '../../data/services/openai_story_service.dart'; 
import '../../data/services/local_user_service.dart'; 
import '../../data/dummy/avatars.dart'; 

final _storyService = OpenAIStoryService();
final _localUserService = LocalUserService(); 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Story> _stories = []; 
  bool _isLoading = true;
  String _currentUsername = 'Misafir'; 
  String _lastLoadedUserId = ''; 
  String? _currentAvatarUrl; 
  bool _isVerified = false; 
  
  // Ebeveyn Modu durumu
  bool _isParentMode = false; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialDataAndVerify();
    });
  }

  // YENİLEME MANTIĞI: Profil ekranından geri dönüldüğünde durumu kontrol eder.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
        _checkAndReloadUser();
    }
  }

  // --- GÜVENLİ VERİ YÜKLEME VE KONTROL METOTLARI ---

  Future<void> _loadInitialDataAndVerify() async {
    await _loadUserData(forceReloadStories: false); 
    if (!mounted) return;

    if (_currentUsername != LocalUserService.defaultUserId) {
      // Sadece ilk yüklemede veya yönlendirmede doğrulama yap
      await _verifyOnLoad(); 
    } else {
      if (mounted) {
        setState(() { 
          _isVerified = true; 
          _isLoading = false; 
        });
      }
    }
    
    if (!mounted) return;

    if (_isVerified && _stories.isEmpty) {
        await _fetchStories();
    }
  }

  Future<void> _checkAndReloadUser() async {
    if (!mounted) return;
    
    // Anlık mevcut durumları kontrol et
    final userId = await _localUserService.getSelectedUserId();
    final avatarUrl = await _localUserService.getSelectedUserAvatar(userId);
    final parentMode = await _localUserService.getIsParentMode(); 
    
    if (!mounted) return;

    // Kullanıcı ID'si, Avatar URL'si veya Ebeveyn Modu değişmişse state'i güncelle
    if (userId != _lastLoadedUserId || avatarUrl != _currentAvatarUrl || parentMode != _isParentMode) {
      
      // Yalnızca kullanıcı değişmişse hikayeleri yeniden yükle
      await _loadUserData(forceReloadStories: userId != _lastLoadedUserId);
      
      // Ebeveyn Modu durumunu set et (Buton bu değere bağımlıdır)
      if(mounted) {
        setState(() { 
          _isParentMode = parentMode; 
        });
      }
    }
  }

  Future<void> _loadUserData({required bool forceReloadStories}) async {
    if (mounted) setState(() => _isLoading = true);

    final userId = await _localUserService.getSelectedUserId();
    if (!mounted) return;

    final fetchedAvatarUrl = await _localUserService.getSelectedUserAvatar(userId); 
    if (!mounted) return;
    
    final parentMode = await _localUserService.getIsParentMode(); // Ebeveyn modunu da yükle
    if (!mounted) return;

    if (!mounted) return;

    setState(() {
      _currentUsername = userId == LocalUserService.defaultUserId ? 'Misafir' : userId;
      _lastLoadedUserId = userId;
      _currentAvatarUrl = fetchedAvatarUrl ?? defaultAvatarUrl; 
      _isParentMode = parentMode; // Durumu kaydet
    });
    
    if (forceReloadStories) {
        await _fetchStories();
    } else {
         if (mounted && (_currentUsername == LocalUserService.defaultUserId || _isVerified)) {
             setState(() { _isLoading = false; });
         }
    }
  }
  
  Future<void> _fetchStories() async {
    final userId = await _localUserService.getSelectedUserId();
    if (!mounted) return;
    
    try {
      final stories = await _storyService.getStoriesForUser(userId); 
      
      if (mounted) {
        setState(() {
          _stories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Hikayeler çekilemedi: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _logoutAndRedirect() async {
    await _localUserService.logoutUser();
    if (mounted) {
        _isVerified = false; 
        context.go(AppRoutes.auth);
    }
  }
  
  void _forceSwitchProfile(String username) async {
    await _localUserService.setSelectedUserId(username);
    if (mounted) {
      _checkAndReloadUser();
    }
  }

  Future<void> _verifyOnLoad() async {
    if (mounted) setState(() { _isLoading = true; });

    final bool success = await _showPasswordVerificationDialog(_currentUsername, isStrict: true);
    if (!mounted) return;
    
    if (success) {
        setState(() { _isVerified = true; });
    } else {
        _logoutAndRedirect(); 
    }
  }

  // --- ŞİFRE DOĞRULAMA DİYALOĞU ---
  Future<bool> _showPasswordVerificationDialog(String targetUsername, {bool isStrict = false}) async {
    final TextEditingController passwordController = TextEditingController();
    
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isStrict, 
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String error = '';
            
            void verify() async {
               if (!dialogContext.mounted) return;
               
               final success = await _localUserService.loginUser(targetUsername, passwordController.text.trim());
               
               if (!dialogContext.mounted) return;

               if (success) {
                  Navigator.pop(dialogContext, true);
               } else {
                  setDialogState(() => error = 'Yanlış şifre');
               }
            }

            return PopScope(
              canPop: !isStrict,
              child: AlertDialog(
                title: Text(isStrict ? 'Giriş Yap: $targetUsername' : 'Şifre Doğrulama'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isStrict) const Text("Devam etmek için şifrenizi doğrulayın."),
                      TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: 'Şifre', errorText: error.isEmpty ? null : error),
                          onSubmitted: (_) => verify(),
                      ),
                    ],
                  ),
                ),
                actions: [
                    if (!isStrict) TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
                    ElevatedButton(
                        onPressed: verify, 
                        child: const Text('Doğrula')
                    ),
                ],
              ),
            );
          }
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showProfileOptions(BuildContext context) async {
    final allUsernames = await _localUserService.getAllRegisteredUsernames();
    if (!mounted) return;

    final switchableUsers = allUsernames.where((name) => name != _currentUsername).toList();
    final bool isGuest = _currentUsername == 'Misafir';

    final List<PopupMenuEntry<String>> menuItems = [
        ...switchableUsers.map((username) => PopupMenuItem<String>(
          value: username,
          child: Text('Geçiş Yap: $username'),
        )).toList(),
        
        if (switchableUsers.isNotEmpty) const PopupMenuDivider(),
        
        PopupMenuItem<String>(
          value: 'logout',
          child: Text(isGuest ? 'Giriş Yap / Kayıt Ol' : 'Başka Biriyle Giriş Yap', 
              style: TextStyle(color: isGuest ? Colors.green : Colors.red)),
        ),
    ];
    
    // PopupMenu'nun pozisyonlandırması için basit bir Rect kullanımı
    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(1000, 100, 0, 0), 
      items: menuItems,
    ).then((value) async { 
      if (!mounted) return; 

      if (value == 'logout') {
        _logoutAndRedirect();
      } else if (value is String) {
        final bool success = await _showPasswordVerificationDialog(value, isStrict: false); 
        if (!mounted) return;

        if (success) {
            _forceSwitchProfile(value);
        }
      }
    });
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isVerified) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final String initialLetter = _currentUsername.isNotEmpty 
        ? _currentUsername[0].toUpperCase() 
        : 'M';
    
    final Widget profileAvatarWidget = CircleAvatar(
        radius: 18,
        backgroundColor: Colors.blueAccent.shade100, 
        backgroundImage: _currentAvatarUrl != null && _currentUsername != 'Misafir'
            ? CachedNetworkImageProvider(_currentAvatarUrl!) as ImageProvider
            : null,
        child: _currentAvatarUrl == null || _currentUsername == 'Misafir'
            ? Text(
                initialLetter,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              )
            : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () async {
            // Profil ekranına gitmek ve geri döndüğünde durumu yenilemek için
            await context.push(AppRoutes.profile); 
          },
          onLongPress: () => _showProfileOptions(context), 
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              profileAvatarWidget, 
              const SizedBox(width: 8),
              Text('($_currentUsername)', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)), 
            ],
          ),
        ), 
        automaticallyImplyLeading: false, 
        actions: [
          // KISITLAMA KONTROLÜ: Yeni hikaye oluşturma butonu sadece Ebeveyn Modu'nda (true) görünür.
          if (_isParentMode)
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () => context.push(AppRoutes.create),
            ),
          
          IconButton( 
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _stories = [];
                _isLoading = true;
              });
              _fetchStories(); 
            },
          ),
          const SizedBox(width: 8), 
        ]
      ),
      body: _stories.isEmpty 
             ? Center(
                 child: Text(
                   _currentUsername == 'Misafir' 
                   ? "Giriş yapın ve kendi hikayelerinizi oluşturun!"
                   // KISITLAMA METNİ
                   : (_isParentMode 
                        ? "Henüz hikaye yok. (+) butonuna basarak oluşturun." 
                        : "Henüz hikaye yok. Hikaye oluşturmak için Ebeveyn Modunu açın."),
                   textAlign: TextAlign.center,
                 )
               )
             : ListView.builder(
                 itemCount: _stories.length,
                 itemBuilder: (context, index) {
                   final story = _stories[index];
                   return Card(
                     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     child: ListTile(
                       leading: CachedNetworkImage(
                         imageUrl: story.imageUrl,
                         width: 50, height: 50, fit: BoxFit.cover,
                         placeholder: (context, url) => Container(width: 50, height: 50, color: Colors.grey[200]),
                         errorWidget: (context, url, error) => Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.image_not_supported, size: 30)),
                       ),
                       title: Text(story.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                       subtitle: Text(story.text.length > 50 ? '${story.text.substring(0, 50)}...' : story.text),
                       trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                       onTap: () { context.push(AppRoutes.storyDetail.replaceFirst(':id', story.id)); },
                     ),
                   );
                 },
               )
    );
  }
}