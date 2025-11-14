// lib/router/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../presentation/home/home_screen.dart'; 
import '../presentation/create_story/prompt_screen.dart'; 
import '../presentation/home/story_detail_screen.dart'; 
import '../presentation/auth/login_register_screen.dart'; 
import '../presentation/auth/profile_verification_screen.dart'; 
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
  static const String profileSelection = '/profile-select'; 
}

final GoRouter router = GoRouter(
  initialLocation: AppRoutes.home, 
  
  redirect: (BuildContext context, GoRouterState state) async {
    final bool anyUserExists = await _localUserServiceInstance.anyUserRegistered(); // Kayıt var mı?
    final selectedId = await _localUserServiceInstance.getSelectedUserId();
    
    // Geçici olarak Home ekranını açıyorsa ve henüz bir profil seçiliyse
    final bool isUserSelected = selectedId != LocalUserService.defaultUserId; 
    
    final bool isAuthPath = state.uri.path == AppRoutes.auth;
    final bool isProfileSelectPath = state.uri.path == AppRoutes.profileSelection;

    // 1. Durum: Hiç Kayıt Yok (Yeni kullanıcı)
    if (!anyUserExists) {
        // Auth ekranına yönlendir (kayıt ol)
        return isAuthPath ? null : AppRoutes.auth;
    }

    // 2. Durum: Kayıtlı Kullanıcı Var (Her oturumda doğrulanmalı)
    // Home'a veya başka bir yere gitmek istiyorsa VEYA heniz geçerli bir kullanıcı seçilmemişse
    if (!isProfileSelectPath && !isUserSelected) {
        // Profil Seçim ekranına yönlendir
        return AppRoutes.profileSelection;
    }
    
    // 3. Durum: Başarılı Doğrulama Yapılmış ve ana ekrana yönlendiriliyor.
    // Eğer Home'da ise veya Home'a gitmek istiyorsa ve bir kullanıcı seçiliyse.
    if (isUserSelected && (isAuthPath || isProfileSelectPath)) {
        // Zaten giriş yapmışsa (seçim yapılmışsa), Home ekranına yönlendir
        return AppRoutes.home;
    }
    
    // Home ekranına erişim ve kullanıcı seçiliyken: İzin ver.
    return null;
  },

  routes: [
    GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
    GoRoute(path: AppRoutes.create, builder: (context, state) => const PromptScreen()),
    GoRoute(path: AppRoutes.auth, builder: (context, state) => const LoginRegisterScreen()),
    GoRoute(path: AppRoutes.profile, builder: (context, state) => const ProfileScreen()),
    
    // Profil Doğrulama Ekranı
    GoRoute(
      path: AppRoutes.profileSelection,
      builder: (context, state) => const ProfileVerificationScreen(),
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
              return  Scaffold(appBar: AppBar(title: const Text("Hata")), body: const Center(child: Text("Hikaye bulunamadı.")));
            }
            // StoryDetailScreen'inize Story nesnesini iletmelisiniz.
            return StoryDetailScreen(story: snapshot.data!); 
          },
        );
      },
    ),
  ],
);