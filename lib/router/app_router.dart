// lib/router/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../presentation/home/home_view_model.dart'; 
import '../presentation/create_story/prompt_screen.dart'; 
import '../presentation/home/story_detail_screen.dart'; 
import '../presentation/auth/login_register_screen.dart'; 
import '../data/services/firestore_story_service.dart'; 
import '../data/services/local_user_service.dart'; 

final _firestoreService = FirestoreStoryService();
final _localUserService = LocalUserService(); 

class AppRoutes {
  static const String home = '/'; // Ana Sayfa (Root)
  static const String create = '/create';
  static const String storyDetail = '/story-detail/:id';
  static const String auth = '/auth'; // Giriş/Kayıt Ekranı
}

final GoRouter router = GoRouter(
  initialLocation: AppRoutes.home, 
  
  redirect: (BuildContext context, GoRouterState state) async {
    final selectedId = await _localUserService.getSelectedUserId();
    final bool isLoggedIn = selectedId != LocalUserService.defaultUserId;
    
    // state.uri.path GoRouter'ın güncel API'sidir
    final bool isLoggingIn = state.uri.path == AppRoutes.auth; 

    // 1. Durum: Giriş yapmamışsa
    if (!isLoggedIn) {
      return isLoggingIn ? null : AppRoutes.auth;
    }

    // 2. Durum: Giriş yapmışsa
    if (isLoggingIn) {
      return AppRoutes.home;
    }

    return null;
  },

  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.create,
      builder: (context, state) => const PromptScreen(),
    ),
    GoRoute(
      path: AppRoutes.storyDetail,
      builder: (context, state) {
        final storyId = state.pathParameters['id'];
        
        return FutureBuilder(
          future: _firestoreService.getStoryById(storyId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return Scaffold(appBar:  AppBar(title: Text("Hata")), body: const Center(child: Text("Hikaye bulunamadı veya bir hata oluştu.")));
            }
            return StoryDetailScreen(story: snapshot.data!);
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => const LoginRegisterScreen(),
    ),
  ],
);