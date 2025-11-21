// lib/data/services/firestore_story_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../dummy/stories.dart';

class FirestoreStoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'stories'; 

  // Hikayeyi Firestore'a kaydeder ve Firestore ID'sini döndürür
  Future<String> saveStory(Story story) async {
    final docRef = await _firestore.collection(_collection).add(
      story.toMap(),
    );
    return docRef.id;
  }

  // Firestore ID'si ile tek bir hikayeyi çeker
  Future<Story?> getStoryById(String id) async {
    // id boşsa null döndür
    if (id.isEmpty) return null; 

    final docSnapshot = await _firestore.collection(_collection).doc(id).get();
    
    if (docSnapshot.exists && docSnapshot.data() != null) {
      return Story.fromMap(docSnapshot.data()!, docSnapshot.id);
    }
    return null;
  }
  
  // HAFTA 5 HAZIRLIĞI: Tüm public hikayeleri çeker
  Future<List<Story>> getPublicStories() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20) // İlk 20 hikaye
        .get();

    return snapshot.docs.map((doc) => Story.fromMap(doc.data(), doc.id)).toList();
  }

  // Hikayeyi siler
  Future<void> deleteStory(String storyId) async {
    if (storyId.isEmpty) return;
    await _firestore.collection(_collection).doc(storyId).delete();
  }
}