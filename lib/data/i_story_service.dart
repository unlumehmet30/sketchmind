// lib/data/i_story_service.dart

import '../data/dummy/stories.dart';

abstract class IStoryService {
  Future<Story> createStory(String prompt);
  Future<void> saveStory(Story story); // Artık kullanılmayacak ama kontratta kalmalı
  Future<List<Story>> getPublicStories(); 
}