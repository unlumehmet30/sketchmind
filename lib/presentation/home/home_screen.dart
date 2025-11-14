// lib/presentation/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../data/dummy/stories.dart'; 
import '../../router/app_router.dart';
import '../../data/services/openai_story_service.dart'; 
import '../../data/services/local_user_service.dart'; 
import '../../data/dummy/avatars.dart'; // defaultAvatarUrl için

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

  @override
  void initState() {
    super.initState();
    // Yükleme didChangeDependencies'e devredilmiştir.
  }

  // Sayfa her açıldığında veya geri dönüldüğünde çağrılır
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndReloadUser();
  }

  // Kullanıcı değişmişse yeniden yükle
  Future<void> _checkAndReloadUser() async {
    final userId = await _localUserService.getSelectedUserId();
    final avatarUrl = await _localUserService.getSelectedUserAvatar(userId);
    
    // Kullanıcı ID'si VEYA Avatar URL'si değişmişse yeniden yükle
    if (userId != _lastLoadedUserId || avatarUrl != _currentAvatarUrl) {
      await _loadUserData(forceReloadStories: userId != _lastLoadedUserId);
    }
  }

  // Kullanıcı adını ve avatar URL'sini yükler
  Future<void> _loadUserData({required bool forceReloadStories}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final userId = await _localUserService.getSelectedUserId();
    final fetchedAvatarUrl = await _localUserService.getSelectedUserAvatar(userId); 
    
    await Future.delayed(const Duration(milliseconds: 500)); 

    if (mounted) {
      setState(() {
        _currentUsername = userId == LocalUserService.defaultUserId ? 'Misafir' : userId;
        _lastLoadedUserId = userId;
        _currentAvatarUrl = fetchedAvatarUrl ?? defaultAvatarUrl; 
      });
    }
    
    if (forceReloadStories) {
        await _fetchStories();
    } else if (mounted) {
         setState(() { _isLoading = false; });
    }
  }
  
  Future<void> _fetchStories() async {
    final userId = await _localUserService.getSelectedUserId();
    
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hikayeler yüklenirken bir sorun oluştu.')),
        );
      }
    }
  }

  void _logoutAndRedirect() async {
    await _localUserService.logoutUser();
    if (mounted) {
      context.go(AppRoutes.auth);
    }
  }
  
  // GÜVENLİĞİ GEÇEN KULLANICI İÇİN PROFİL DEĞİŞTİRME
  void _forceSwitchProfile(String username) async {
    await _localUserService.setSelectedUserId(username);
    
    if (mounted) {
      _checkAndReloadUser();
    }
  }
  
  // ŞİFRE DOĞRULAMA DİALOGU
  Future<void> _showPasswordVerificationDialog(String targetUsername) async {
    final TextEditingController passwordController = TextEditingController();
    
    final bool? verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Giriş: $targetUsername'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Şifre'),
          onSubmitted: (value) => Navigator.of(context).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );

    if (verified == true) {
      final password = passwordController.text.trim(); 
      
      final bool loginSuccess = await _localUserService.loginUser(targetUsername, password);
      
      if (loginSuccess) {
        // Başarılı doğrulama sonrası profili değiştir
        _forceSwitchProfile(targetUsername);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hata: Şifre yanlış.')),
          );
        }
      }
    }
    passwordController.dispose();
  }


  // Profil değiştirme menüsünü gösterir (UZUN BASIŞ İŞLEVİ)
  Future<void> _showProfileOptions(BuildContext context) async {
    final allUsernames = await _localUserService.getAllRegisteredUsernames();

    final switchableUsers = allUsernames
        .where((name) => name != _currentUsername)
        .toList();
    
    final bool isGuest = _currentUsername == 'Misafir';

    final List<PopupMenuEntry<String>> menuItems = [
        // Kullanıcı Listesi: Seçilince şifre dialogunu açar
        ...switchableUsers.map((username) => PopupMenuItem<String>(
          value: username,
          child: Text('Geçiş Yap: $username'),
        )).toList(),
        
        if (switchableUsers.isNotEmpty) const PopupMenuDivider(),
        
        // Başka Biriyle Giriş Yap (Auth ekranına yönlendirir)
        PopupMenuItem<String>(
          value: 'logout',
          child: Text(isGuest ? 'Giriş Yap / Kayıt Ol' : 'Başka Biriyle Giriş Yap', 
              style: TextStyle(color: isGuest ? Colors.green : Colors.red)),
        ),
    ];
    
    final RenderBox toolbar = context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        toolbar.localToGlobal(Offset.zero),
        toolbar.localToGlobal(toolbar.size.bottomLeft(Offset.zero)),
      ),
      Offset.zero & MediaQuery.of(context).size,
    );

    await showMenu(
      context: context,
      position: position, 
      items: menuItems,
    ).then((value) {
      if (value == 'logout') {
        _logoutAndRedirect();
      } else if (value is String) {
        // ✅ DÜZELTME: Şifre doğrulamayı başlat
        _showPasswordVerificationDialog(value); 
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
                   : "Bu profile ait hikaye yok.\nİlk hikayeyi siz oluşturun!",
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
                         width: 50,
                         height: 50,
                         fit: BoxFit.cover,
                         placeholder: (context, url) => Container(
                           width: 50, 
                           height: 50, 
                           color: Colors.grey[200],
                           child: const Center(
                             child: CircularProgressIndicator(strokeWidth: 2),
                           ),
                         ),
                         errorWidget: (context, url, error) => Container(
                           width: 50,
                           height: 50,
                           color: Colors.grey[300],
                           child: const Icon(Icons.image_not_supported, size: 30),
                         ),
                       ),
                       title: Text(
                         story.title,
                         style: const TextStyle(fontWeight: FontWeight.bold),
                       ),
                       subtitle: Text(
                         story.text.length > 50
                             ? '${story.text.substring(0, 50)}...'
                             : story.text,
                       ),
                       trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                       onTap: () {
                         context.push(
                           AppRoutes.storyDetail.replaceFirst(':id', story.id),
                         );
                       },
                     ),
                   );
                 },
               )
    );
  }
}