// lib/data/services/firestore_story_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../dummy/stories.dart';
import 'connectivity_service.dart';

class FirestoreStoryService {
  FirestoreStoryService._internal();
  static final FirestoreStoryService _instance =
      FirestoreStoryService._internal();
  factory FirestoreStoryService() => _instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final ConnectivityService _connectivity = ConnectivityService();
  final String _collection = 'stories';

  static const Duration _operationTimeout = Duration(seconds: 10);
  static const int _maxRetryAttempts = 2;

  // Hikayeyi Firestore'a kaydeder ve Firestore ID'sini döndürür
  Future<String> saveStory(Story story) async {
    await _assertOnlineForWrite('Hikaye kaydi');
    final docRef = await _runWithRetry<DocumentReference<Map<String, dynamic>>>(
      () => _firestore.collection(_collection).add(story.toMap()),
    );
    return docRef.id;
  }

  // Firestore ID'si ile tek bir hikayeyi çeker
  Future<Story?> getStoryById(
    String id, {
    required String requesterUid,
  }) async {
    if (id.isEmpty) return null;

    final docSnapshot =
        await _runWithRetry<DocumentSnapshot<Map<String, dynamic>>>(
      () => _firestore.collection(_collection).doc(id).get(),
    );

    if (docSnapshot.exists && docSnapshot.data() != null) {
      final story = Story.fromMap(docSnapshot.data()!, docSnapshot.id);
      if (_canReadStory(story, requesterUid)) {
        return story;
      }
    }
    return null;
  }

  Future<List<Story>> getPublicStories() async {
    final snapshot = await _runWithRetry<QuerySnapshot<Map<String, dynamic>>>(
      () => _firestore
          .collection(_collection)
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get(),
    );

    return snapshot.docs
        .map((doc) => Story.fromMap(doc.data(), doc.id))
        .toList(growable: false);
  }

  Future<List<Story>> getStoriesForUser({
    required String ownerUid,
    required String userId,
    int limit = 50,
  }) async {
    if (ownerUid.trim().isEmpty || userId.trim().isEmpty) {
      return <Story>[];
    }

    final snapshot = await _runWithRetry<QuerySnapshot<Map<String, dynamic>>>(
      () => _firestore
          .collection(_collection)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(),
    );

    return snapshot.docs
        .map((doc) => Story.fromMap(doc.data(), doc.id))
        .toList(growable: false);
  }

  Future<List<Story>> getContinuations(
    String parentStoryId, {
    required String requesterUid,
  }) async {
    if (parentStoryId.isEmpty) return <Story>[];

    final snapshot = await _runWithRetry<QuerySnapshot<Map<String, dynamic>>>(
      () => _firestore
          .collection(_collection)
          .where('parentStoryId', isEqualTo: parentStoryId)
          .orderBy('chapterIndex')
          .limit(20)
          .get(),
    );

    return snapshot.docs
        .map((doc) => Story.fromMap(doc.data(), doc.id))
        .where((story) => _canReadStory(story, requesterUid))
        .toList(growable: false);
  }

  Future<void> deleteStory(
    String storyId, {
    required String requesterUid,
  }) async {
    if (storyId.isEmpty || requesterUid.trim().isEmpty) return;
    await _assertOnlineForWrite('Hikaye silme');

    final docRef = _firestore.collection(_collection).doc(storyId);

    await _runWithRetry<void>(() {
      return _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          return;
        }

        final story = Story.fromMap(snapshot.data()!, snapshot.id);
        if (story.ownerUid.trim().isEmpty || story.ownerUid != requesterUid) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Bu hikayeyi silme izniniz yok.',
          );
        }

        transaction.delete(docRef);
      });
    });
  }

  bool _canReadStory(Story story, String requesterUid) {
    if (story.isPublic) return true;
    if (requesterUid.trim().isEmpty) return false;
    return story.ownerUid == requesterUid;
  }

  Future<void> _assertOnlineForWrite(String operationName) async {
    final connected = await _connectivity.isConnected();
    if (connected) return;
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: '$operationName icin internet baglantisi gerekli.',
    );
  }

  Future<T> _runWithRetry<T>(Future<T> Function() action) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        return await action().timeout(_operationTimeout);
      } catch (error, stackTrace) {
        lastError = error;
        if (!_shouldRetry(error) || attempt == _maxRetryAttempts) {
          rethrow;
        }
        if (kDebugMode) {
          debugPrint(
            'Firestore operation retry $attempt/$_maxRetryAttempts: $error\n$stackTrace',
          );
        }
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
    }

    throw Exception('Firestore operation failed: $lastError');
  }

  bool _shouldRetry(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      const retryableCodes = <String>{
        'aborted',
        'cancelled',
        'deadline-exceeded',
        'internal',
        'resource-exhausted',
        'unavailable',
      };
      return retryableCodes.contains(error.code);
    }
    return false;
  }
}
