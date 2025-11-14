// lib/router/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../presentation/home/home_screen.dart'; 
import '../presentation/create_story/prompt_screen.dart'; 
import '../presentation/home/story_detail_screen.dart'; 
import '../presentation/auth/login_register_screen.dart'; 
import '../presentation/profile/profile_screen.dart';
import '../data/services/firestore_story_service.dart'; 
import '../data/services/local_user_service.dart'; 

final _firestoreService = FirestoreStoryService();

LocalUserService get _localUserServiceInstance {
  return LocalUserService(); 
}

class AppRoutes {
  static const String home = '/'; 
  static const String create = '/create';
  static const String storyDetail = '/story-detail/:id';
  static const String auth = '/auth'; 
  static const String profile = '/profile'; 
}

final GoRouter router = GoRouter(
  initialLocation: AppRoutes.home, 
  
  redirect: (BuildContext context, GoRouterState state) async {
    final selectedId = await _localUserServiceInstance.getSelectedUserId();
    final bool isLoggedIn = selectedId != LocalUserService.defaultUserId;
    
    final bool isLoggingIn = state.uri.path == AppRoutes.auth; 

    if (!isLoggedIn) {
      return isLoggingIn ? null : AppRoutes.auth;
    }

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
              return  Scaffold(appBar: AppBar(title: Text("Hata")), body: Center(child: Text("Hikaye bulunamadÄ±.")));
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
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);