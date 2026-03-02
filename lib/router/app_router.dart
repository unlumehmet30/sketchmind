// lib/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/dummy/stories.dart';
import '../data/services/auth_service.dart';
import '../data/services/family_settings_service.dart';
import '../data/services/firestore_story_service.dart';
import '../data/services/local_user_service.dart';
import '../data/services/screen_time_service.dart';
import '../presentation/auth/login_register_screen.dart';
import '../presentation/auth/profile_verification_screen.dart';
import '../presentation/create_story/prompt_screen.dart';
import '../presentation/home/home_screen.dart';
import '../presentation/home/story_detail_screen.dart';
import '../presentation/profile/profile_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String create = '/create';
  static const String storyDetail = '/story-detail/:id';
  static const String auth = '/auth';
  static const String profile = '/profile';
  static const String profileSelection = '/profile-select';
}

class AppRouterDependencies {
  const AppRouterDependencies({
    required this.firestoreService,
    required this.authService,
    required this.localUserService,
    required this.familySettingsService,
    required this.screenTimeService,
  });

  final FirestoreStoryService firestoreService;
  final AuthService authService;
  final LocalUserService localUserService;
  final FamilySettingsService familySettingsService;
  final ScreenTimeService screenTimeService;
}

GoRouter createAppRouter({
  AppRouterDependencies? dependencies,
}) {
  final deps = dependencies ??
      AppRouterDependencies(
        firestoreService: FirestoreStoryService(),
        authService: AuthService(),
        localUserService: LocalUserService(),
        familySettingsService: FamilySettingsService(),
        screenTimeService: ScreenTimeService(),
      );

  final guardSnapshotCache = _RouteGuardSnapshotCache(
    familySettingsService: deps.familySettingsService,
    screenTimeService: deps.screenTimeService,
  );

  Future<Story?> loadStoryForActiveUser(String storyId) async {
    final uid = await deps.authService.getCurrentUserId();
    return deps.firestoreService.getStoryById(
      storyId,
      requesterUid: uid,
    );
  }

  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (BuildContext context, GoRouterState state) async {
      final access = await deps.localUserService.getRouteAccessState();
      final isAuthPath = state.uri.path == AppRoutes.auth;
      final isProfileSelectPath = state.uri.path == AppRoutes.profileSelection;
      final path = state.uri.path;
      final isStoryDetailPath = path.startsWith('/story-detail/');

      if (!access.anyUserExists) {
        return isAuthPath ? null : AppRoutes.auth;
      }

      if (!access.isUserSelected) {
        if (isAuthPath) return null;
        return isProfileSelectPath ? null : AppRoutes.profileSelection;
      }

      if (isProfileSelectPath) {
        return AppRoutes.home;
      }

      if (!access.isParentMode && !access.devModeBypass) {
        if (path == AppRoutes.create || isStoryDetailPath) {
          final snapshot = await guardSnapshotCache.load();

          if (snapshot.screenTimeStatus.isLimitReached) {
            return AppRoutes.home;
          }

          if (path == AppRoutes.create &&
              snapshot.familySettings.isWithinQuietHours(DateTime.now())) {
            return AppRoutes.home;
          }
        }
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
        path: AppRoutes.auth,
        builder: (context, state) => const LoginRegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSelection,
        builder: (context, state) => const ProfileVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.storyDetail,
        builder: (context, state) {
          final storyId = state.pathParameters['id']?.trim();
          if (storyId == null || storyId.isEmpty) {
            return const _StoryRouteErrorScreen(
              message: 'Hikaye kimligi gecersiz.',
            );
          }
          return _StoryDetailLoader(
            storyId: storyId,
            loadStory: loadStoryForActiveUser,
          );
        },
      ),
    ],
  );
}

final GoRouter router = createAppRouter();

class _StoryDetailLoader extends StatefulWidget {
  const _StoryDetailLoader({
    required this.storyId,
    required this.loadStory,
  });

  final String storyId;
  final Future<Story?> Function(String storyId) loadStory;

  @override
  State<_StoryDetailLoader> createState() => _StoryDetailLoaderState();
}

class _StoryDetailLoaderState extends State<_StoryDetailLoader> {
  late final Future<Story?> _storyFuture;

  @override
  void initState() {
    super.initState();
    _storyFuture = widget.loadStory(widget.storyId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Story?>(
      future: _storyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const _StoryRouteErrorScreen(
            message: 'Hikaye bulunamadi.',
          );
        }

        return StoryDetailScreen(story: snapshot.data!);
      },
    );
  }
}

class _StoryRouteErrorScreen extends StatelessWidget {
  const _StoryRouteErrorScreen({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hata')),
      body: Center(child: Text(message)),
    );
  }
}

class _RouteGuardSnapshotCache {
  _RouteGuardSnapshotCache({
    required FamilySettingsService familySettingsService,
    required ScreenTimeService screenTimeService,
  })  : _familySettingsService = familySettingsService,
        _screenTimeService = screenTimeService;

  final FamilySettingsService _familySettingsService;
  final ScreenTimeService _screenTimeService;

  _RouteGuardSnapshot? _cached;
  DateTime? _cachedAt;
  Future<_RouteGuardSnapshot>? _inFlight;
  static const Duration _ttl = Duration(seconds: 8);

  Future<_RouteGuardSnapshot> load() async {
    final now = DateTime.now();
    if (_cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _ttl) {
      return _cached!;
    }

    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _build();
    _inFlight = future;
    try {
      final snapshot = await future;
      _cached = snapshot;
      _cachedAt = DateTime.now();
      return snapshot;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  Future<_RouteGuardSnapshot> _build() async {
    final familySettings = await _familySettingsService.getSettings();
    final screenTimeStatus = await _screenTimeService.getStatus(
      limitEnabled: familySettings.screenTimeLimitEnabled,
      dailyLimitMinutes: familySettings.dailyScreenTimeLimitMinutes,
    );
    return _RouteGuardSnapshot(
      familySettings: familySettings,
      screenTimeStatus: screenTimeStatus,
    );
  }
}

class _RouteGuardSnapshot {
  const _RouteGuardSnapshot({
    required this.familySettings,
    required this.screenTimeStatus,
  });

  final FamilySafetySettings familySettings;
  final ScreenTimeStatus screenTimeStatus;
}
