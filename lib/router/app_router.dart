import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../presentation/home/home_view_model.dart'; // HomeScreen
import '../presentation/create_story/prompt_screen.dart'; // PromptScreen (Şimdi oluşturacağız)
import '../presentation/home/story_detail_screen.dart'; // StoryDetailScreen
import '../data/dummy/stories.dart'; // Story sınıfı

// Route İsimleri
class AppRoutes {
  static const String home = '/';
  static const String create = '/create';
  static const String storyDetail = '/story-detail/:id'; // Parametreli rota
}

final GoRouter router = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    // 1. Ana Keşfet Sayfası (Hafta 5'te tam Keşfet olacak)
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    
    // 2. Hikaye Oluşturma/Prompt Ekranı (Şimdi Kodlayacağımız Ekran)
    GoRoute(
      path: AppRoutes.create,
      builder: (context, state) => const PromptScreen(),
    ),
    
    // 3. Hikaye Detay Sayfası
    GoRoute(
      path: AppRoutes.storyDetail,
      builder: (context, state) {
        // Rota parametresinden ID'yi alıyoruz
        final storyId = state.pathParameters['id'];
        
        // Dummy veriden ilgili hikayeyi bulalım
        final story = dummyStories.firstWhere(
          (s) => s.id == storyId,
          // Hikaye bulunamazsa boş bir Story döndürmek veya hata ekranı göstermek için
          orElse: () => dummyStories.first, 
        );
        
        // StoryDetailScreen artık Story nesnesini değil, ID'yi almalıdır.
        // Ancak şimdilik dummy veriyi kullanmak için nesneyi gönderelim.
        // Hafta 4'te ID ile Firebase'den çekeceğiz.
        return StoryDetailScreen(story: story);
      },
    ),
  ],
);