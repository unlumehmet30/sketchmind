// lib/presentation/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart'; // HAFTA 7: YENİ İMPORT
import '../../data/dummy/stories.dart'; 
import '../../router/app_router.dart';
import '../../data/services/openai_story_service.dart'; 

final _storyService = OpenAIStoryService();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Story> _publicStories = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPublicStories(); 
  }

  Future<void> _fetchPublicStories() async {
    try {
      final stories = await _storyService.getPublicStories();
      setState(() {
        _publicStories = stories;
        _isLoading = false;
      });
    } catch (e) {
      print("Public hikayeler çekilemedi: $e");
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hikayeler yüklenirken bir sorun oluştu. (Konsolu kontrol edin)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Keşfet"), 
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => context.push(AppRoutes.create),
          ),
          IconButton( 
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _publicStories = [];
              });
              _fetchPublicStories();
            },
          ),
        ]
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _publicStories.isEmpty 
             ? const Center(
                 child: Text(
                   "Henüz paylaşılmış hikaye yok.\nİlk hikayeyi siz oluşturun!",
                   textAlign: TextAlign.center,
                 )
               )
             : ListView.builder( 
                 itemCount: _publicStories.length,
                 itemBuilder: (context, index) {
                   final story = _publicStories[index];
                   return Card(
                     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     child: ListTile(
                       // HAFTA 7: Image.network yerine CachedNetworkImage kullanılıyor
                       leading: CachedNetworkImage(
                         imageUrl: story.imageUrl,
                         width: 50,
                         height: 50,
                         fit: BoxFit.cover,
                         placeholder: (context, url) => Container(width: 50, height: 50, color: Colors.grey[200]),
                         errorWidget: (context, url, error) => const Icon(Icons.error_outline, size: 50),
                       ),
                       title: Text(story.title),
                       subtitle: Text(
                         story.text.length > 50
                             ? '${story.text.substring(0, 50)}...'
                             : story.text,
                       ),
                       onTap: () {
                         context.go(
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