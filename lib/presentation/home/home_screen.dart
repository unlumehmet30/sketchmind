// lib/presentation/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../data/dummy/stories.dart'; 
import '../../router/app_router.dart';
import '../../data/services/openai_story_service.dart'; 
import '../../data/services/local_user_service.dart'; 

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
  String _lastLoadedUserId = ''; // Son yüklenen kullanıcıyı tutmak için

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
    
    // Kullanıcı değişmişse veya ilk yüklemeyse
    if (userId != _lastLoadedUserId) {
      await _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final userId = await _localUserService.getSelectedUserId();
    
    if (mounted) {
      setState(() {
        _currentUsername = userId == LocalUserService.defaultUserId ? 'Misafir' : userId;
        _isLoading = true;
        _lastLoadedUserId = userId;
      });
    }
    
    await _fetchStories();
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

  @override
  Widget build(BuildContext context) {
    final String initialLetter = _currentUsername.isNotEmpty 
        ? _currentUsername[0].toUpperCase() 
        : 'M';

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            // Profile sayfasına git
            await context.push(AppRoutes.profile);
            // Profile'dan döndükten sonra kullanıcı değişmişse yeniden yükle
            _checkAndReloadUser();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueAccent.shade100, 
                child: Text(
                  initialLetter,
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.blue
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _currentUsername, 
                style: const TextStyle(fontSize: 18)
              ), 
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stories.isEmpty 
             ? Center(
                 child: Padding(
                   padding: const EdgeInsets.all(24.0),
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(
                         Icons.auto_stories_outlined,
                         size: 80,
                         color: Colors.grey.shade400,
                       ),
                       const SizedBox(height: 20),
                       Text(
                         _currentUsername == 'Misafir' 
                         ? "Giriş yapın ve kendi hikayelerinizi oluşturun!"
                         : "Bu profile ait hikaye yok.\nİlk hikayeyi siz oluşturun!",
                         textAlign: TextAlign.center,
                         style: TextStyle(
                           fontSize: 18,
                           color: Colors.grey.shade600,
                         ),
                       ),
                     ],
                   ),
                 ),
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