// lib/router/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../presentation/home/home_view_model.dart'; // HomeScreen yolu
import '../presentation/create_story/prompt_screen.dart'; 
import '../presentation/home/story_detail_screen.dart'; 
import '../data/services/firestore_story_service.dart'; // Firestore Servisi

final _firestoreService = FirestoreStoryService();

class AppRoutes {
  static const String home = '/';
  static const String create = '/create';
  static const String storyDetail = '/story-detail/:id'; 
}

final GoRouter router = GoRouter(
  initialLocation: AppRoutes.home, 
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.create,
      builder: (context, state) => const PromptScreen(),
    ),
    
    // YENİ: Firestore'dan ID ile hikaye çekme
    GoRoute(
      path: AppRoutes.storyDetail,
      builder: (context, state) {
        final storyId = state.pathParameters['id'];
        
        // Asenkron olarak hikayeyi çekerken bir yükleme ekranı gösteriyoruz
        return FutureBuilder(
          future: _firestoreService.getStoryById(storyId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return  Scaffold(
                appBar:  AppBar(title: Text("Hata")),
                body: Center(child: Text("Hikaye bulunamadı veya bir hata oluştu.")),
              );
            }
            
            // Başarılı: StoryDetailScreen'i çağır
            return StoryDetailScreen(story: snapshot.data!);
          },
        );
      },
    ),
  ],
);