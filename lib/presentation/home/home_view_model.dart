import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // GoRouter eklendi
import '../../data/dummy/stories.dart'; // Story class ve dummyStories
import '../../router/app_router.dart'; // Route isimleri ve GoRouter rotaları

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Yüklenme simülasyonu
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hikayeler"),
        actions: [
          // YENİ BUTON: Prompt Ekranına Geçiş
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () {
              // GoRouter ile /create yoluna yönlendirme
              context.go(AppRoutes.create); 
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: dummyStories.length,
              itemBuilder: (context, index) {
                final story = dummyStories[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Image.asset(
                      story.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(story.title),
                    subtitle: Text(
                      story.text.length > 30
                          ? '${story.text.substring(0, 30)}...'
                          : story.text,
                    ),
                    onTap: () {
                      // Yönlendirme artık GoRouter ile yapılacak
                      // Parametre olarak hikaye ID'sini gönderiyoruz
                      context.go(
                        AppRoutes.storyDetail.replaceFirst(':id', story.id),
                      );
                    },
                      
                  ),
                );
              },
            ),
    );
  }
}


