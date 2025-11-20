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
    
    final bool isUserSelected = selectedId != LocalUserService.defaultUserId; // Bir kullanıcı seçili mi?
    
    final bool isAuthPath = state.uri.path == AppRoutes.auth;
    final bool isProfileSelectPath = state.uri.path == AppRoutes.profileSelection;

    // --- Durum 1: Hiç Kayıt Yok (Yeni Kurulum) ---
    if (!anyUserExists) {
        // Eğer Auth ekranında değilse, oraya yönlendir. Auth'ta ise kalmasına izin ver (return null).
        return isAuthPath ? null : AppRoutes.auth;
    }

    // --- Durum 2: Kullanıcı Seçimi Gerekli (Kayıtlı kullanıcılar var ama seçili profil yok) ---
    if (anyUserExists && !isUserSelected) {
        
        // **ÇÖZÜM:** Kullanıcı Auth ekranına gitmek istiyorsa ("Yeni Profil Oluştur" butonu), buna izin ver.
        if (isAuthPath) {
            return null; // Auth ekranına gitmesine izin ver.
        }
        
        // Kullanıcı Home veya başka bir yere gitmek istiyorsa, Profile Selection ekranına zorla.
        return isProfileSelectPath ? null : AppRoutes.profileSelection;
    }
    
    // --- Durum 3: Giriş Yapılmış (isUserSelected = true) ---
    // Kullanıcı giriş yapmışsa ve Auth veya Profile Selection ekranına gitmeye çalışıyorsa, Home'a yönlendir.
    if (isUserSelected && (isAuthPath || isProfileSelectPath)) {
        return AppRoutes.home;
    }
    
    // Diğer tüm durumlar (Home, Create, Detail, Profile, vb.): İzin ver.
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